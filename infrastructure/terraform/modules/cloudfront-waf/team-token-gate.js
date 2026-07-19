
function handler(event) {
    var request = event.request;
    var cookies = request.cookies;
    var expectedToken = "TEAM_TOKEN_PLACEHOLDER";

    var providedToken = null;
    if (request.querystring && request.querystring.token) {
        providedToken = request.querystring.token.value;
    }
    if (!providedToken && cookies.team_token) {
        providedToken = cookies.team_token.value;
    }

    if (providedToken === expectedToken) {
        if (request.querystring && request.querystring.token) {
            return {
                statusCode: 302,
                statusDescription: "Found",
                headers: {
                    location: { value: "/" }
                },
                cookies: {
                    team_token: {
                        value: expectedToken,
                        attributes: "Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=86400"
                    }
                }
            };
        }
        return request;
    }

    return {
        statusCode: 403,
        statusDescription: "Forbidden",
        headers: { "content-type": { value: "text/plain" } },
        body: "Access denied."
    };
}