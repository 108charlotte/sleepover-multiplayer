function copyToClipboard(text) {
    navigator.clipboard.writeText(text).catch(function(err) {
        // fallback for older browsers
        var el = document.createElement('textarea');
        el.value = text;
        document.body.appendChild(el);
        el.select();
        document.execCommand('copy');
        document.body.removeChild(el);
    });
}