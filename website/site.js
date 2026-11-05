// Turns each .tabs block into accessible tabs. Without this script every
// panel shows in turn with its own heading.
(function () {
  var groups = document.querySelectorAll('.tabs');
  var saved = {};
  try {
    saved = JSON.parse(localStorage.getItem('nestling-tabs') || '{}');
  } catch (e) {}

  groups.forEach(function (group, g) {
    var panels = Array.prototype.filter.call(group.children, function (el) {
      return el.tagName === 'SECTION';
    });
    if (panels.length < 2) return;
    var key = group.getAttribute('data-sync');
    var list = document.createElement('div');
    list.className = 'tablist';
    list.setAttribute('role', 'tablist');
    var tabs = panels.map(function (panel, i) {
      var heading = panel.querySelector('h3');
      var label = heading ? heading.textContent : 'Tab ' + (i + 1);
      var tab = document.createElement('button');
      tab.type = 'button';
      tab.id = 'tab-' + g + '-' + i;
      tab.textContent = label;
      tab.setAttribute('role', 'tab');
      panel.id = panel.id || 'panel-' + g + '-' + i;
      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', tab.id);
      panel.tabIndex = 0;
      tab.setAttribute('aria-controls', panel.id);
      list.appendChild(tab);
      return tab;
    });

    function select(index, focus) {
      tabs.forEach(function (tab, i) {
        var on = i === index;
        tab.setAttribute('aria-selected', on ? 'true' : 'false');
        tab.tabIndex = on ? 0 : -1;
        panels[i].hidden = !on;
      });
      if (focus) tabs[index].focus();
    }

    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () {
        select(i);
        if (!key) return;
        saved[key] = tab.textContent;
        try {
          localStorage.setItem('nestling-tabs', JSON.stringify(saved));
        } catch (e) {}
        // Keep other tab groups with the same key on the same choice.
        document.querySelectorAll('.tabs[data-sync="' + key + '"] [role=tab]').forEach(function (other) {
          if (other !== tab && other.textContent === tab.textContent && other.getAttribute('aria-selected') !== 'true') other.click();
        });
      });
      tab.addEventListener('keydown', function (e) {
        var next = { ArrowRight: i + 1, ArrowLeft: i - 1, Home: 0, End: tabs.length - 1 }[e.key];
        if (next === undefined) return;
        e.preventDefault();
        select((next + tabs.length) % tabs.length, true);
      });
    });

    group.insertBefore(list, group.firstChild);
    group.classList.add('is-tabbed');
    var start = 0;
    if (key && saved[key]) {
      tabs.forEach(function (tab, i) {
        if (tab.textContent === saved[key]) start = i;
      });
    }
    select(start);
  });
})();
