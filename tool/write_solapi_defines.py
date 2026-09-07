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


_AUTH_CODES = (
    "InvalidAPIKey",
    "InvalidSignature",
    "SignatureDoesNotMatch",
    "InvalidDateInfo",
    "RequestTimeTooSkewed",
    "DuplicatedSignature",
)


def _solapi_error_fields(body: str):
    try:
        parsed = json.loads(body)
    except ValueError:
        return "", ""
    if not isinstance(parsed, dict):
        return "", ""
    return (
        str(parsed.get("errorCode") or ""),
        str(parsed.get("errorMessage") or "")[:180],
    )


def verify_solapi_hmac(api_key: str, api_secret: str) -> None:
    """앱에 넣기 전에 솔라피가 이 Key/Secret 쌍을 받는지 확인한다.

    공식 HMAC 예제와 같은 GET /messages/v4/list 를 쓴다.
    잔고 URL은 웹 HTML 을 줄 수 있어, 본문에 signature 만 있어도
    키 짝이 틀렸다고 빌드를 죽이면 안 된다.
    """
    import hashlib
    import hmac
    import urllib.error
    import urllib.request
    from datetime import datetime, timezone

    now = datetime.now(timezone.utc)
    date = "%04d-%02d-%02dT%02d:%02d:%02dZ" % (
        now.year,
        now.month,
        now.day,
        now.hour,
        now.minute,
        now.second,
    )
    salt = os.urandom(16).hex()
    signature = hmac.new(
        api_secret.encode("utf-8"),
        (date + salt).encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
    auth = "HMAC-SHA256 apiKey=%s, date=%s, salt=%s, signature=%s" % (
        api_key,
        date,
        salt,
        signature,
    )
    req = urllib.request.Request(
        "https://api.solapi.com/messages/v4/list",
        headers={
            "Authorization": auth,
            "Accept": "application/json",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            print("SOLAPI HMAC ok (HTTP %s)" % res.status)
            return
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        code, message = _solapi_error_fields(body)
        print("SOLAPI HMAC HTTP %s errorCode=%s" % (e.code, code or "(none)"))
        if message:
            print("SOLAPI HMAC errorMessage=%s" % message)
        if code in _AUTH_CODES:
            sys.exit(
                "SOLAPI HMAC rejected (%s). "
                "solapi 그룹 Key/Secret 짝을 솔라피 콘솔에서 다시 넣으세요."
                % code
            )
        if e.code in (200, 404) or (200 <= e.code < 300):
            print("SOLAPI HMAC ok (HTTP %s)" % e.code)
            return
        # 2xx가 아닌데 인증 코드도 없으면 엔드포인트/네트워크 문제.
        # 키 짝이 틀렸다고 단정하지 않는다. 로그의 errorCode를 본다.
        sys.exit(
            "SOLAPI HMAC check failed HTTP %s errorCode=%s. AAB를 올리지 마세요."
            % (e.code, code or "(none)")
        )
    except Exception as e:
        sys.exit("SOLAPI HMAC check network error: %s" % e)


verify_solapi_hmac(defs["SOLAPI_API_KEY"], defs["SOLAPI_API_SECRET"])
