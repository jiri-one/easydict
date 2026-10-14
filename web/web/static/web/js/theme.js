// Loaded in <head>, so that the theme is set before the page is drawn. "theme" in localStorage
// is the key of the Django admin too, so both share the choice; the original colours are its
// "auto" (the admin then follows the system).
(function () {
    var themes = ["auto", "light", "dark"];
    var root = document.documentElement;
    var stored = null;
    try {
        stored = localStorage.getItem("theme");
    } catch (error) {
        // storage blocked: the original colours
    }
    root.dataset.theme = themes.indexOf(stored) >= 0 ? stored : "auto";

    document.addEventListener("DOMContentLoaded", function () {
        document.querySelectorAll(".theme-toggle").forEach(function (button) {
            button.addEventListener("click", function () {
                var theme = themes[(themes.indexOf(root.dataset.theme) + 1) % themes.length];
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
