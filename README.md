# dcape-app-prom5s
================================================================================

[![GitHub Release][1]][2] [![GitHub code size in bytes][3]]() [![GitHub license][4]][5]

[1]: https://img.shields.io/github/release/dopos/dcape-app-redmine.svg
[2]: https://github.com/dopos/dcape-app-redmine/releases
[3]: https://img.shields.io/github/languages/code-size/dopos/dcape-app-redmine.svg
[4]: https://img.shields.io/github/license/dopos/dcape-app-redmine.svg
[5]: LICENSE

[Prometheus](http://prometheus.io) application set for monitoring and deploy of [dcape](https://github.com/dopos/dcape).



## **Prom5s** consist of the components and use official images (containers):

* Prometheus (metrics database)
* AlertManager (alerts management)
* Grafana (visualize metrics)
* NodeExporter (host metrics exporter)
* cAdvisor (containers metrics exporter)
* Postgres_exporter (container metrics exporter)

## Requirements

* linux 64bit (git, make, wget, gawk, openssl)
* [docker](http://docker.io)
* [dcape](https://github.com/dopos/dcape)
* Git service ([github](https://github.com), [gitea](https://gitea.io) or [gogs](https://gogs.io))

## For deploy this application package om dcape

* Fork this repo in your Git service
* Setup deploy hook
* Run "Test delivery" (config sample will be created in dcape)
* Edit and save config (enable deploy etc)
* Run "Test delivery" again (app will be installed and started on webhook host)
* Reset admin password for Grafana

About usage **prom5s** see [instruction](https://github.com/abhinand-tw/dcape-app-prom5s/blob/master/usage_prom5s.md)

See also: [Deploy setup](https://github.com/dopos/dcape/blob/master/DEPLOY.md) (in Russian)

## License

The MIT License (MIT), see [LICENSE](LICENSE).

2018 Maxim Danilin <zan@whiteants.net>
