
Tuning PostgreSQL config by your hardware. Based on original [gregs1104/pgtune](https://github.com/gregs1104/pgtune) and [le0pard/pgtune](https://github.com/le0pard/pgtune).

Usage
=====

```bash
$ bash pgtune.sh --help

# Sample
$ bash pgtune.sh \
    --db-version 10 \
    --db-type dw \
    --os-type linux \
    --memory 3GB \
    --hd-type hdd \
    --cpu 2
```