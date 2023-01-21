# feeds
Simple feeds proxy for circumventing CORS problems

For more details see this blog post:

* [Proxying Web Feeds with Dancer2](https://dev.to/davorg/proxying-web-feeds-with-dancer2-on1)

**Note:** If you're trying this out you need to run it using a multi-threaded
web server, for example Starman.

    plackup -s Starman app.psgi
