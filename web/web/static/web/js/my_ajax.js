const form = document.getElementById('main_search_form');
const results = document.getElementById('results');
let searchController;
let speech;

form.addEventListener('submit', async (event) => {
    event.preventDefault();
    searchController?.abort();
    const controller = new AbortController();
    searchController = controller;
    results.innerText = form.dataset.loading;
    results.setAttribute('aria-busy', 'true');
    try {
        const response = await fetch('/search', {
            body: new FormData(form),
            method: 'post',
            signal: controller.signal,
        });
        const data = await response.text();
        if (controller.signal.aborted) return;
        if (response.ok) {
            results.innerHTML = data;
        } else {
            results.innerText = form.dataset.error + ' ' + data;
        }
    } catch (error) {
        if (!controller.signal.aborted) {
            results.innerText = form.dataset.error + ' ' + error.message;
        }
    } finally {
        if (searchController === controller) results.removeAttribute('aria-busy');
    }
});

async function speak(button) {
    const status = button.closest('details, .result-group').querySelector('[role="status"]');
    status.innerText = '';
    speech?.pause();
    const audio = new Audio('/api/speech?' + new URLSearchParams({
        lang: button.dataset.speechLanguage,
        q: button.dataset.speechText,
    }));
    speech = audio;
    try {
        await audio.play();
    } catch (_) {
        if (speech === audio && status.isConnected) {
            status.innerText = form.dataset.speechFailed;
            status.scrollIntoView({block: 'nearest', behavior: 'instant'});
        }
    }
}

results.addEventListener('click', async (event) => {
    const speechButton = event.target.closest('button[data-speech-text]');
    if (speechButton) {
        speak(speechButton);
        return;
    }
    const lookup = event.target.closest('button[data-lookup-text]');
    if (lookup) {
        form.elements.searched_text.value = lookup.dataset.lookupText;
        form.elements.language.value = lookup.dataset.lookupLanguage;
        results.focus({preventScroll: true});
        form.requestSubmit();
        return;
    }
    const copy = event.target.closest('button[data-copy-text]');
    if (copy) {
        const detail = copy.closest('details');
        const status = detail.querySelector('[role="status"]');
        let message;
        try {
            await navigator.clipboard.writeText(copy.dataset.copyText);
            message = form.dataset.copied;
        } catch (_) {
            message = form.dataset.copyFailed;
        }
        if (status.isConnected && detail.open) {
            status.innerText = message;
            status.scrollIntoView({block: 'nearest', behavior: 'instant'});
        }
    }
});

results.addEventListener('toggle', (event) => {
    if (event.target instanceof HTMLDetailsElement && !event.target.open) {
        event.target.querySelector('[role="status"]').innerText = '';
    }
}, true);
