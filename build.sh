#!/bin/sh
# Builds index.html (the web page) from game.html (the page body, also used as the claude.ai artifact).
set -e
cd "$(dirname "$0")"
{
  printf '%s\n' '<!doctype html><html lang="da"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
  printf '%s\n' '<meta name="theme-color" content="#0d1a14"><meta name="apple-mobile-web-app-capable" content="yes"><meta name="mobile-web-app-capable" content="yes">'
  printf '%s\n' '<link rel="manifest" href="manifest.webmanifest"><link rel="apple-touch-icon" href="icon-192.png"><link rel="icon" href="icon-192.png">'
  printf '%s\n' '<style>html,body{margin:0}</style><script src="peerjs.min.js"></script></head><body>'
  cat game.html
  printf '%s\n' '</body></html>'
} > index.html
