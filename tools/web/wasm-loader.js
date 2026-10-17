// Redirect only Godot's engine request; other requests use fetch normally.
(() => {
    const wasmURL = new URL("index.wasm", document.currentScript.src).href;
    const fetchAsset = window.fetch.bind(window);
    window.fetch = async (input, options) => {
        const url = new URL(input instanceof Request ? input.url : input, document.baseURI);
        if (url.href !== wasmURL) {
            return fetchAsset(input, options);
        }
        if (typeof DecompressionStream === "undefined") {
            throw new Error("This game needs a browser with gzip DecompressionStream support. Please update your browser.");
        }
        const response = await fetchAsset(
            input instanceof Request ? new Request(`${wasmURL}.gz`, input) : `${wasmURL}.gz`,
            options,
        );
        if (!response.ok) {
            throw new Error(`Could not load the game engine (HTTP ${response.status}).`);
        }
        return new Response(response.body.pipeThrough(new DecompressionStream("gzip")), {
            headers: { "Content-Type": "application/wasm" },
        });
    };
})();
