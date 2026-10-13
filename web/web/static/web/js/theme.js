// Colour themes: the original colours, high contrast white ("light") and high contrast
// black ("dark"); the switch goes through them in this order. Loaded in <head>, so the
// theme is set before the page is drawn. The choice is stored in localStorage under
// "theme", the key the Django admin uses too, so the site and its admin share it; the
// original colours are stored as the admin's "auto" (the admin then follows the system).
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
