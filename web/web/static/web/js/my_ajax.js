var form = document.getElementById('main_search_form');
form.onsubmit = function (event) {
    var formData = new FormData(form);
    document.getElementById('results').innerText = "Loading..."
    fetch("/search",
        {
            body: formData,
            method: "post"
        }).then(async function (response) {
            let data = await response.text();
            if (response.ok == true) {
                document.getElementById('results').innerHTML = data;
            } else {
                document.getElementById('results').innerText = "There is some error: " + data
            }
        }
        );

    //Dont submit the form.
    return false;
}
