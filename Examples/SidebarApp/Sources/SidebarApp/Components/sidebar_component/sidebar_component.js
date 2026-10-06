document.querySelectorAll("[data-sidebar-toggle]").forEach((toggle) => {
  toggle.addEventListener("click", () => {
    toggle.closest("[data-sidebar-section]").classList.toggle("sidebar__section--collapsed");
  });
});
