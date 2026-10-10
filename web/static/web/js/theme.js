// Light/dark mode. Loaded in <head>, so the theme is set before the page is drawn.
// The choice is stored in localStorage under "theme", the key the Django admin uses too,
// so the site and its admin share it. Without a choice (or with the admin's "auto")
// the system preference decides.
(function () {
    var root = document.documentElement;
    var stored = null;
    try {
        stored = localStorage.getItem("theme");
    } catch (error) {
        // storage blocked: just follow the system
    }
    if (stored === "light" || stored === "dark") {
        root.dataset.theme = stored;
    } else {
        root.dataset.theme = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll(".theme-toggle").forEach(function (button) {
            button.addEventListener("click", function () {
                var theme = root.dataset.theme === "dark" ? "light" : "dark";
                root.dataset.theme = theme;
                try {
                    localStorage.setItem("theme", theme);
                } catch (error) {
                    // the theme still changes for this page
                }
            });
        });
    });
})();
