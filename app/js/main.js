/* claude-first-project — progressive enhancement only.
   Every page renders and is navigable with JavaScript disabled. */

(function () {
  'use strict';

  /* ---------- Mobile navigation ---------- */
  var toggle = document.querySelector('.nav__toggle');
  var menu = document.getElementById('nav-menu');

  if (toggle && menu) {
    toggle.addEventListener('click', function () {
      var open = menu.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', String(open));
    });
  }

  /* ---------- Footer year ---------- */
  var yearEl = document.querySelector('[data-year]');
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  /* ---------- Deployment stamp ----------
     build-info.json is written by scripts/build.sh at build time and shipped
     alongside the HTML. Reading it at runtime means the footer reflects the
     deploy that produced the files on THIS instance — reloading behind the
     load balancer can surface a different instance mid-rollout. */
  var timeEl = document.querySelector('[data-deployed-at]');
  var commitEl = document.querySelector('[data-commit]');

  if (timeEl) {
    fetch('build-info.json', { cache: 'no-store' })
      .then(function (res) {
        if (!res.ok) { throw new Error('HTTP ' + res.status); }
        return res.json();
      })
      .then(function (info) {
        var stamp = info.deployedAt;
        var parsed = new Date(stamp);

        if (isNaN(parsed.getTime())) {
          timeEl.textContent = 'unknown';
          return;
        }

        timeEl.dateTime = parsed.toISOString();
        timeEl.textContent = parsed.toLocaleString(undefined, {
          dateStyle: 'medium',
          timeStyle: 'short'
        });

        if (commitEl && info.commit) {
          commitEl.textContent = String(info.commit).slice(0, 7);
          commitEl.title = 'Commit ' + info.commit;
        }
      })
      .catch(function () {
        // Served straight from source without a build step — not an error.
        timeEl.textContent = 'not built';
      });
  }

  /* ---------- Contact form ----------
     No backend by design: the site is static files on Nginx. Validation and
     confirmation happen client-side. */
  var form = document.getElementById('contact-form');
  if (!form) { return; }

  var status = document.getElementById('form-status');

  function setError(field, message) {
    var slot = form.querySelector('[data-error-for="' + field.name + '"]');
    if (slot) { slot.textContent = message; }
    field.setAttribute('aria-invalid', message ? 'true' : 'false');
  }

  function validate(field) {
    var value = field.value.trim();

    if (!value) {
      setError(field, 'This field is required.');
      return false;
    }
    if (field.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)) {
      setError(field, 'Enter a valid email address.');
      return false;
    }
    setError(field, '');
    return true;
  }

  var fields = Array.prototype.slice.call(
    form.querySelectorAll('input[required], textarea[required]')
  );

  fields.forEach(function (field) {
    field.addEventListener('blur', function () { validate(field); });
  });

  form.addEventListener('submit', function (event) {
    event.preventDefault();

    // Validate every field so all errors surface at once, not just the first.
    var allValid = fields.map(validate).every(Boolean);

    if (!allValid) {
      status.textContent = 'Please fix the highlighted fields.';
      status.className = 'form__status is-err';
      return;
    }

    status.textContent = 'Thanks — your message has been recorded.';
    status.className = 'form__status is-ok';
    form.reset();
    fields.forEach(function (field) { field.setAttribute('aria-invalid', 'false'); });
  });
})();
