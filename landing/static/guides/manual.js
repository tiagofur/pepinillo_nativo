/* Pepinillo — manuales de usuario: progreso de lectura, scrollspy y
 * índice en drawer (móvil). Vanilla, sin dependencias, compartido por
 * todas las guías de /guides/. */
(function () {
	'use strict';

	var progress = document.getElementById('progress');
	var links = Array.prototype.slice.call(document.querySelectorAll('aside nav a[href^="#"]'));
	var byId = {};
	links.forEach(function (a) {
		byId[a.getAttribute('href').slice(1)] = a;
	});
	var sections = Array.prototype.slice.call(document.querySelectorAll('main section[id]'));

	/* Progreso + scrollspy en un solo handler de scroll */
	var ticking = false;
	function onScroll() {
		if (ticking) return;
		ticking = true;
		window.requestAnimationFrame(function () {
			ticking = false;

			if (progress) {
				var doc = document.documentElement;
				var max = doc.scrollHeight - doc.clientHeight;
				progress.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + '%';
			}

			if (sections.length) {
				var y = window.scrollY;
				var current = sections[0];
				var atBottom =
					window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4;
				if (atBottom) {
					current = sections[sections.length - 1];
				} else {
					for (var i = 0; i < sections.length; i++) {
						if (sections[i].offsetTop - 180 <= y) current = sections[i];
					}
				}
				/* cae hacia atrás hasta la sección más cercana que sí esté en el índice */
				var active = null;
				for (var j = sections.indexOf(current); j >= 0 && !active; j--) {
					active = byId[sections[j].id];
				}
				if (active && !active.classList.contains('active')) {
					links.forEach(function (a) {
						a.classList.remove('active');
					});
					active.classList.add('active');
				}
			}
		});
	}
	window.addEventListener('scroll', onScroll, { passive: true });
	onScroll();

	/* Índice en drawer (móvil) */
	var aside = document.querySelector('aside');
	var toggle = document.getElementById('toc-toggle');
	var overlay = document.getElementById('toc-overlay');

	function closeToc() {
		if (!aside) return;
		aside.classList.remove('open');
		if (overlay) overlay.classList.remove('open');
		if (toggle) toggle.setAttribute('aria-expanded', 'false');
	}

	if (toggle && aside) {
		toggle.addEventListener('click', function () {
			var open = aside.classList.toggle('open');
			if (overlay) overlay.classList.toggle('open', open);
			toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
		});
		if (overlay) overlay.addEventListener('click', closeToc);
		links.forEach(function (a) {
			a.addEventListener('click', closeToc);
		});
		window.addEventListener('keydown', function (e) {
			if (e.key === 'Escape') closeToc();
		});
	}
})();
