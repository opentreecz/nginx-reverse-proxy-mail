# Patches

Drop backported security fixes here to apply them at build time, ahead of
the next upstream nginx/OpenSSL point release.

```
docker/patches/
├── nginx/     *.patch files applied with `patch -p1` against the nginx source tree
└── openssl/   *.patch files applied with `patch -p1` against the OpenSSL source tree
```

Both directories are empty by default. The Dockerfile applies every
`*.patch` file it finds, in filename order, so prefix filenames with a number
(`01-cve-xxxx-nnnn.patch`) when order matters. Once the fix ships in an
official nginx/OpenSSL release and `docker/NGINX_VERSION` /
`docker/OPENSSL_VERSION` are bumped past it, remove the patch.
