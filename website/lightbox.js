const imageLightbox = document.getElementById('image-lightbox');

if (imageLightbox && typeof imageLightbox.showModal === 'function') {
  const image = imageLightbox.querySelector('.lightbox-image');
  const caption = imageLightbox.querySelector('.lightbox-caption');
  const closeButton = imageLightbox.querySelector('button');

  document.querySelectorAll('.screenshot-link').forEach((link) => {
    link.setAttribute('aria-haspopup', 'dialog');
    link.addEventListener('click', (event) => {
      if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
        return;
      }

      event.preventDefault();
      const thumbnail = link.querySelector('img');
      image.src = link.href;
      image.alt = thumbnail.alt;
      image.width = Number(thumbnail.getAttribute('width'));
      image.height = Number(thumbnail.getAttribute('height'));
      caption.textContent = link.closest('figure').querySelector('figcaption span').textContent;
      link.focus({ preventScroll: true });
      imageLightbox.showModal();
    });
  });

  imageLightbox.addEventListener('keydown', (event) => {
    // Close is the preview's only focusable control.
    if (event.key === 'Tab' && !event.ctrlKey && !event.metaKey && !event.altKey) {
      event.preventDefault();
      closeButton.focus();
    }
  });

  imageLightbox.addEventListener('click', (event) => {
    if (event.target !== imageLightbox) {
      return;
    }

    const bounds = imageLightbox.getBoundingClientRect();
    if (event.clientX < bounds.left || event.clientX > bounds.right ||
        event.clientY < bounds.top || event.clientY > bounds.bottom) {
      imageLightbox.close();
    }
  });
}
