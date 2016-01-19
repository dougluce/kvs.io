!function t(e, n, r) {
    function o(a, c) {
        if (!n[a]) {
            if (!e[a]) {
                var s = "function" == typeof require && require;
                if (!c && s) return s(a, !0);
                if (i) return i(a, !0);
                var u = new Error("Cannot find module '" + a + "'");
                throw u.code = "MODULE_NOT_FOUND", u
            }
            var f = n[a] = {
                exports: {}
            };
            e[a][0].call(f.exports, function(t) {
                var n = e[a][1][t];
                return o(n ? n : t)
            }, f, f.exports, t, e, n, r)
        }
        return n[a].exports
    }
    for (var i = "function" == typeof require && require, a = 0; a < r.length; a++) o(r[a]);
    return o
}({
    1: [function(t) {
        "use strict";
        var e = function(t) {
            return t && t.__esModule ? t["default"] : t
        },
        n = e(t("./analytics")),
        r = e(t("./supports"));
        if (!r.flexbox()) {
            var o = document.createElement("div");
            o.className = "Error", o.innerHTML = "Your browser does not support Flexbox.\n                   Parts of this site may not appear as expected.", document.body.insertBefore(o, document.body.firstChild)
        }
    }, {
        "./analytics": 3,
        "./supports": 6
    }],
    2: [function(t, e) {
        "use strict";
        e.exports = function(t, e, n) {
            t.addEventListener ? t.addEventListener(e, n, !1) : t.attachEvent("on" + e, n)
        }
    }, {}],
    3: [function(t, e) {
        "use strict";


        function i(t) {
            var e = s(t.href),
            n = s(location.href);
            return e.origin != n.origin
        }
        var a = function(t) {
            return t && t.__esModule ? t["default"] : t
        },
        c = a(t("./link-clicked")),
        s = a(t("./parse-url")),
        u = {
            xs: "(max-width: 383px)",
            sm: "(min-width: 384px) and (max-width: 575px)",
            md: "(min-width: 576px) and (max-width: 767px)",
            lg: "(min-width: 768px)"
        };
    }, {
        "./link-clicked": 4,
        "./parse-url": 5
    }],
    4: [function(t, e) {
        "use strict";

        function n(t) {
            return t.nodeName && "a" == t.nodeName.toLowerCase() && t.href
        }

        function r(t) {
            if (n(t)) return t;
            for (; t.parentNode && 1 == t.parentNode.nodeType;) {
                if (n(t)) return t;
                t = t.parentNode
            }
        }
        var o = function(t) {
            return t && t.__esModule ? t["default"] : t
        },
        i = o(t("./add-listener"));
        e.exports = function(t) {
            i(document, "click", function(e) {
                var n = e || window.event,
                o = n.target || n.srcElement,
                i = r(o);
                i && t.call(i, n)
            })
        }
    }, {
        "./add-listener": 2
    }],
    5: [function(t, e) {
        "use strict";
        var n = document.createElement("a"),
        r = {};
        e.exports = function(t) {
            if (r[t]) return r[t];
            var e = /:80$/,
            o = /:443$/;
            n.href = t;
            var i = n.protocol && ":" != n.protocol ? n.protocol : location.protocol,
            a = "80" == n.port || "443" == n.port ? "" : n.port,
            c = n.host.replace("http:" == i ? e : o, ""),
            s = n.origin ? n.origin : i + "//" + c,
            u = "/" == n.pathname.charAt(0) ? n.pathname : "/" + n.pathname;
            return r[t] = {
                hash: n.hash,
                host: c,
                hostname: n.hostname,
                href: n.href,
                origin: s,
                path: u + n.search,
                pathname: u,
                port: a,
                protocol: i,
                search: n.search
            }
        }
    }, {}],
    6: [function(t, e) {
        "use strict";
        var n = {},
        r = document.body.style;
        e.exports = {
            flexbox: function() {
                return n.flexbox || (n.flexbox = "flexBasis" in r || "msFlexAlign" in r || "webkitBoxDirection" in r)
            }
        }
    }, {}]
}, {}, [1]);
