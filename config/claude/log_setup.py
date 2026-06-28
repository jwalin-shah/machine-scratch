"""log_setup -- structured logging for bootstrap Python scripts.

Usage:
    from log_setup import get_logger
    log = get_logger("my-script")
    log.info("msg", extra={"key": "val"})

Design:
  - stdlib `logging` only (no pip deps on bootstrap path)
  - JSON structured format with timestamps
  - Stderr output (never interferes with stdout pipelines)
  - DEBUG level hidden unless LOG_LEVEL=debug in env
"""
import logging
import os
import sys


def get_logger(name, level=None):
    if level is None:
        level = os.environ.get("LOG_LEVEL", "info").upper()
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger
    logger.setLevel(getattr(logging, level, logging.INFO))
    handler = logging.StreamHandler(sys.stderr)
    handler.setFormatter(logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%S%z",
    ))
    logger.addHandler(handler)
    return logger
