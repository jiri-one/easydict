// the texts are in the form's data attributes, in the language of the page
var form = document.getElementById('main_search_form');
var results = document.getElementById('results');
form.onsubmit = function (event) {
    results.innerText = form.dataset.loading;
    fetch("/search", {
        body: new FormData(form),
        method: "post"
    }).then(async function (response) {
        var data = await response.text();
        if (response.ok) {
            results.innerHTML = data;
        } else {
            results.innerText = form.dataset.error + " " + data;
        }
    }).catch(function (error) {
        results.innerText = form.dataset.error + " " + error.message;
    });
    // no page reload
    return false;
};
