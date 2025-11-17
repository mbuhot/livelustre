export function focus(root, selector) {
  // Use setTimeout to ensure the DOM has been updated
  setTimeout(() => {
    let element = null;

    // Search within the provided root (could be shadow root or regular element)
    if (root && root.querySelector) {
      element = root.querySelector(selector);
    }

    // Fallback to document-level search
    if (!element) {
      element = document.querySelector(selector);
    }

    if (element) {
      element.focus();
    } else {
      console.warn(
        "Could not find element to focus:",
        selector,
        "in root:",
        root,
      );
    }
  }, 10);
}

// localStorage helpers
export function saveToLocalStorage(key, value) {
  try {
    // value is a Gleam Json object, stringify it for localStorage
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.error("Failed to save to localStorage:", e);
  }
}

export function loadFromLocalStorage(key) {
  try {
    // Check if we're in a browser environment
    if (typeof window === "undefined" || typeof localStorage === "undefined") {
      return null;
    }
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : null;
  } catch (e) {
    console.error("Failed to load from localStorage:", e);
    return null;
  }
}

export function removeFromLocalStorage(key) {
  try {
    // Check if we're in a browser environment
    if (typeof window === "undefined" || typeof localStorage === "undefined") {
      return;
    }
    localStorage.removeItem(key);
  } catch (e) {
    console.error("Failed to remove from localStorage:", e);
  }
}

// URL management - generic functions for working with query parameters
export function updateUrlParams(params) {
  try {
    // Check if we're in a browser environment
    if (typeof window === "undefined" || !window.history) {
      return;
    }
    const url = new URL(window.location);

    // params is a Gleam Dict that comes in as an array of [key, value] tuples
    // in JavaScript representation
    for (const [key, value] of params) {
      url.searchParams.set(key, value);
    }

    window.history.pushState({}, "", url);
  } catch (e) {
    console.error("Failed to update URL params:", e);
  }
}

export function getUrlParams() {
  try {
    // Check if we're in a browser environment
    if (typeof window === "undefined") {
      return [];
    }
    const params = new URLSearchParams(window.location.search);

    // Convert URLSearchParams to an array of [key, value] tuples
    // which will be decoded as a Gleam Dict
    return Array.from(params.entries());
  } catch (e) {
    console.error("Failed to get URL params:", e);
    return [];
  }
}
