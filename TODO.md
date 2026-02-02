# Sidebar Fixes TODO

## Issues to Fix
- [x] Selected page hover effect width should take full collapsed nav bar width and be centered
- [x] Remove or fix the thick left blue stick for active item in collapsed state
- [x] Center the lines that separate sections when nav is collapsed
- [x] Show search icon when nav is collapsed to remove weird space
- [x] Fix search icon disappearing when expanding and not reappearing when collapsing again
- [x] Fix triangular appearance of active nav item hover effect

## Implementation Steps
- [x] Update CSS in style.css for nav-active collapsed state: full width, remove right blue stick, add left blue stick if needed
- [x] Adjust CSS for section divider centering in collapsed state
- [x] Update main.js to add separate search icon element for collapsed state
- [x] Update CSS for search icon visibility in collapsed state
- [x] Fix JavaScript to properly toggle search input visibility instead of container
- [x] Soften edges of active nav item to avoid triangular appearance
- [x] Test sidebar in collapsed and expanded states

## Files to Edit
- [x] frontend/assets/css/style.css
- [x] frontend/assets/js/main.js
