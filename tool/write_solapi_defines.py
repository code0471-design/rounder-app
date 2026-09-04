#!/usr/bin/env python3
"""Codemagic env → solapi_defines.json. bash가 Secret의 $ 를 먹지 않게 한다.

로그에는 길이·템플릿 ID만 남긴다. Key/Secret 값은 출력하지 않는다.
"""
import json
import os
import sys

ROUNDER_OTP = "KA01TP260827200825010BAkqpx4TyCt"
ONECLUB_OTP = "KA01TP2608272010352785egDZKZOntL"
LEGACY_OTP = "UnnQDOxu0b"


def env(name: str, default: str = "") -> str:
    raw = os.environ.get(name, default)
    s = (raw or "").strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in ('"', "'"):
        s = s[1:-1].strip()
    return s


defs = {
    "SOLAPI_API_KEY": env("SOLAPI_API_KEY"),
    "SOLAPI_API_SECRET": env("SOLAPI_API_SECRET"),
    "SOLAPI_OTP_TEMPLATE_ID": env("SOLAPI_OTP_TEMPLATE_ID", ROUNDER_OTP),
    "SOLAPI_TEMPLATE_ID_SCHEDULE_UPLOAD": env(
        "SOLAPI_TEMPLATE_ID_SCHEDULE_UPLOAD",
        "KA01TP260819165935819h6YMQUQnxD6",
    ),
    "SOLAPI_TEMPLATE_ID_SCHEDULE_CHANGE": env(
        "SOLAPI_TEMPLATE_ID_SCHEDULE_CHANGE",
        "KA01TP260819170717941dD6OSJifLZy",
    ),
    "SOLAPI_TEMPLATE_ID_D1": env(
        "SOLAPI_TEMPLATE_ID_D1", "KA01TP260819170856743YpkKVjb5WfS"
    ),
    "SOLAPI_TEMPLATE_ID_SCHEDULE_CANCEL": env(
        "SOLAPI_TEMPLATE_ID_SCHEDULE_CANCEL",
        "KA01TP260819170942410EzVbYmO06U2",
    ),
    "SOLAPI_TEMPLATE_ID_DUES_NUDGE": env(
        "SOLAPI_TEMPLATE_ID_DUES_NUDGE", "KA01TP2608191713271305WAQ7IzWNzo"
    ),
    "SOLAPI_TEMPLATE_ID_DUES_REQUEST": env(
        "SOLAPI_TEMPLATE_ID_DUES_REQUEST", "KA01TP260819171813223rmS1ByutYaw"
    ),
    "SOLAPI_TEMPLATE_ID_GROUP_FINALIZE": env(
        "SOLAPI_TEMPLATE_ID_GROUP_FINALIZE",
        "KA01TP260819170319298NrCEHKRX6u3",
    ),
    "SOLAPI_KAKAO_PF_ID": env(
        "SOLAPI_KAKAO_PF_ID", "KA01PF260819163601284VyeVGcfZZWg"
    ),
    "SOLAPI_SENDER_PHONE": env("SOLAPI_SENDER_PHONE", "01045110471"),
}

print("SOLAPI_API_KEY length=%d" % len(defs["SOLAPI_API_KEY"]))
print("SOLAPI_API_SECRET length=%d" % len(defs["SOLAPI_API_SECRET"]))
print("SOLAPI_OTP_TEMPLATE_ID=%s" % defs["SOLAPI_OTP_TEMPLATE_ID"])
print("SOLAPI_KAKAO_PF_ID=%s" % defs["SOLAPI_KAKAO_PF_ID"])

if not defs["SOLAPI_API_KEY"] or not defs["SOLAPI_API_SECRET"]:
    sys.exit("solapi group missing SOLAPI_API_KEY or SOLAPI_API_SECRET")

otp = defs["SOLAPI_OTP_TEMPLATE_ID"]
if otp in (ONECLUB_OTP, LEGACY_OTP):
    sys.exit(
        "SOLAPI_OTP_TEMPLATE_ID is OneClub/legacy (%s) — ROUND ER needs %s"
        % (otp, ROUNDER_OTP)
    )

with open("solapi_defines.json", "w", encoding="utf-8") as f:
    json.dump(defs, f)
