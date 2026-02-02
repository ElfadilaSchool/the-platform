// frontend/assets/js/pageHeader.js

/**
 * Loads a page-specific header (title and subtitle) into a target element.
 * Assumes translations.js is loaded for dynamic translation.
 *
 * @param {string} targetElementId The ID of the element where the header should be injected.
 * @param {string} titleKey The translation key for the main title.
 * @param {string} subtitleKey The translation key for the subtitle.
 * @param {string} defaultTitle The default title text if translation fails or is not available.
 * @param {string} defaultSubtitle The default subtitle text if translation fails or is not available.
 */
function loadPageHeader(targetElementId, titleKey, subtitleKey, defaultTitle, defaultSubtitle) {
    const targetElement = document.getElementById(targetElementId);
    if (!targetElement) {
        console.error(`Target element with ID '${targetElementId}' not found for page header.`);
        return;
    }

    const headerHtml = `
        <div class="page-header-content max-w-7xl mx-auto px-4 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
                <h1 class="text-xl font-semibold text-gray-900" data-translate="${titleKey}">${defaultTitle}</h1>
                <p class="text-sm text-gray-600" data-translate="${subtitleKey}">${defaultSubtitle}</p>
            </div>
        </div>
    `;

    targetElement.innerHTML = headerHtml;

    // Ensure translations are applied after header content is loaded
    // This assumes updatePageTranslations is available from translations.js
    if (typeof updatePageTranslations === 'function') {
        updatePageTranslations();
    } else {
        console.warn('updatePageTranslations is not defined. Translations might not be applied to page header.');
    }
}
