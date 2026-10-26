import 'package:flutter/widgets.dart';
import 'package:vector_graphics/vector_graphics.dart';

class Logo extends StatelessWidget {
  const Logo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => VectorGraphic(
    loader: const AssetBytesLoader('assets/logo.svg'),
    width: size,
    height: size,
  );
}
