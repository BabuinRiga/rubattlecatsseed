vcl 4.1;

backend default none;

backend bc {
    .host = "127.0.0.1";
    .port = "13599";
}

sub vcl_recv {
    if (req.http.host == "bc.godfat.org") {
        set req.backend_hint = bc;
        set req.http.Cache-Control = "max-age=1800";
        unset req.http.Cookie;
    }
}

sub vcl_backend_response {
    set beresp.ttl = 30m;
}

sub vcl_deliver {
    set resp.http.Cache-Control = "public, max-age=1800";
}
