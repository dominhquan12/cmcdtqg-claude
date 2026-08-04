#!/usr/bin/env bash
# GET /api/v1/ptcb/du-an/search
# Token JWT tu ky bang RSA_PRIVATE_KEY trong .env (chi de test cuc bo, het han sau 24h ke tu luc sinh).

curl --location 'http://localhost:8085/api/v1/ptcb/du-an/search?page=0&size=20&sortBy=createdAt&sortDir=desc' --header 'Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxNjMiLCJ1bmlxdWVfbmFtZSI6Im1vYml0ZXN0IiwiRG9uVmlJZCI6IjQzIiwicm9sZSI6WyJTeXNfQWRtaW4iXSwiU2l0ZUlkIjoiMDAwMDEiLCJpc3MiOiJzZXJ2ZXIiLCJpYXQiOjE3ODU4NTI0MjAsImV4cCI6MTc4NTkzODgyMH0.jdwJdeSM2ApvbUqYv0TiKogf5ztnSHzy_SyU1JiPZaQ6qd4z7s0TLK7lM-myvJ242QNs2OkjIAS8En-sX9fRiNg_wK5UTIzPUP-Tc9cMU_C09Mr4cSUDu1Dm0M0c98V-7_DrnkZ2ylqnnQii9ejJgLGcZUy3bu9VhshN77HXKUOEiREcwK-0xe0pPS18EEQTCJEz-ukzpNUXtflhkn44ofzqexpiLNsq6zuHJUO14Z59-Cfm_N_95t3BStTKjWApm2MEbfoxt7gsgzfjSddvwn4_Hg9mszY59j-Pe8v7eZREl1MmD3PUTGpyWXN_GzHmd6c5rRxD_BXab5T2D9qmwg' --header 'ngonngu: VN'
