
function handler(event) {
    var request = event.request;
    var cookies = request.cookies;
    var expectedToken = "TEAM_TOKEN_PLACEHOLDER";

    var providedToken = null;
    if (request.querystring && request.querystring.token) {
        providedToken = request.querystring.token.value;
    }
    if (!providedToken && cookies && cookies.team_token) {
        providedToken = cookies.team_token.value;
    }

    if (providedToken === expectedToken) {
        // Token arrives via query string — set cookie and redirect to
        // the same path without the token parameter so it is not
        // visible in the URL or browser history.
        if (request.querystring && request.querystring.token) {
            // Rebuild the path, keeping any non-token query params.
            var uri = request.uri || "/";
            var otherParams = [];
            var keys = Object.keys(request.querystring);
            for (var i = 0; i < keys.length; i++) {
                if (keys[i] !== "token") {
                    otherParams.push(keys[i] + "=" + request.querystring[keys[i]].value);
                }
            }
            var redirectUri = uri;
            if (otherParams.length > 0) {
                redirectUri += "?" + otherParams.join("&");
            }

            return {
                statusCode: 302,
                statusDescription: "Found",
                headers: {
                    location: { value: redirectUri }
                },
                cookies: {
                    team_token: {
                        value: expectedToken,
                        attributes: "Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=604800"
                    }
                }
            };
        }
        // Cookie-based access — pass through to origin.
        return request;
    }

    return {
        statusCode: 403,
        statusDescription: "Forbidden",
        headers: { "content-type": { value: "text/plain" } },
        body: "Access denied. Append ?token=YOUR_TOKEN to the URL."
    };
}