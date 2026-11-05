"""Quantization keeps the voice small enough to bundle with the app."""
import json
import struct
import sys

import numpy as np
import onnx
from onnx import numpy_helper

model = onnx.load(sys.argv[1])
config = json.load(open(sys.argv[2], encoding='utf-8'))
tensors = {tensor.name: numpy_helper.to_array(tensor) for tensor in model.graph.initializer}
# The export froze weight-normalised convolutions under generated names; their biases kept theirs.
weights = {node.input[2]: node.input[1] for node in model.graph.node
           if node.op_type in ('Conv', 'ConvTranspose') and len(node.input) > 2}


def conv(prefix):
    return [weights[f'{prefix}.bias'], f'{prefix}.bias']


def norm(prefix):
    return [f'{prefix}.gamma', f'{prefix}.beta']


def separable(prefix):
    names = []
    for layer in range(3):
        names += conv(f'{prefix}.convs_sep.{layer}') + norm(f'{prefix}.norms_1.{layer}')
        names += conv(f'{prefix}.convs_1x1.{layer}') + norm(f'{prefix}.norms_2.{layer}')
    return names


# The order in which the constructors in vits.cpp read them.
order = ['sid']  # The phoneme embedding, misnamed by the export.
for layer in range(6):
    attention = f'enc_p.encoder.attn_layers.{layer}'
    for part in 'qkvo':
        order += conv(f'{attention}.conv_{part}')
    order += [f'{attention}.emb_rel_k', f'{attention}.emb_rel_v']
    order += norm(f'enc_p.encoder.norm_layers_1.{layer}')
    order += conv(f'enc_p.encoder.ffn_layers.{layer}.conv_1')
    order += conv(f'enc_p.encoder.ffn_layers.{layer}.conv_2')
    order += norm(f'enc_p.encoder.norm_layers_2.{layer}')
order += conv('enc_p.proj')
order += conv('dp.pre') + separable('dp.convs') + conv('dp.proj')
for flow in (7, 5, 3):
    order += conv(f'dp.flows.{flow}.pre') + separable(f'dp.flows.{flow}.convs') + conv(f'dp.flows.{flow}.proj')
exponent = next(name for name in tensors if name.startswith('onnx::Exp'))
order += ['dp.flows.0.m', exponent]
for flow in (6, 4, 2, 0):
    order += conv(f'flow.flows.{flow}.pre')
    for layer in range(4):
        order += conv(f'flow.flows.{flow}.enc.in_layers.{layer}')
        order += conv(f'flow.flows.{flow}.enc.res_skip_layers.{layer}')
    order += conv(f'flow.flows.{flow}.post')
order += conv('dec.conv_pre')
for stage in range(3):
    order += conv(f'dec.ups.{stage}')
    for block in range(3):
        for layer in range(2):
            order += conv(f'dec.resblocks.{stage * 3 + block}.convs.{layer}')
order += ['dec.conv_post.weight']

packed = sorted(name for name in tensors if tensors[name].size > 1)
assert sorted(order) == packed, set(order) ^ set(packed)


def write(out, name):
    """Measured on speech: at these depths the voice moves less than between two noise seeds."""
    bits = 12 if name.startswith(('dec.', 'dp.', 'onnx::Exp')) else 8
    tensor = tensors[name].astype(np.float64).ravel()
    low = tensor.min()
    step = max(tensor.max() - low, 1e-12) / (2 ** bits - 1)
    levels = np.round((tensor - low) / step)
    out.write(struct.pack('<Iff', bits > 8, low, step))
    out.write(levels.astype('<u2' if bits > 8 else 'u1').tobytes())


phonemes = sorted((ord(symbol), ids[0]) for symbol, ids in config['phoneme_id_map'].items())
with open(sys.argv[3], 'wb') as out:
    out.write(b'EDV1')
    inference = config['inference']
    out.write(struct.pack('<ifff', config['audio']['sample_rate'], inference['noise_scale'],
                          inference['length_scale'], inference['noise_w']))
    out.write(struct.pack('<i', len(phonemes)))
    for codepoint, identifier in phonemes:
        out.write(struct.pack('<ii', codepoint, identifier))
    for name in order:
        write(out, name)
