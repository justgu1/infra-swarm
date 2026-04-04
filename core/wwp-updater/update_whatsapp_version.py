#!/usr/bin/env python3
"""
update_whatsapp_version.py
Evolution API v2.3.7+ busca a versão do WA automaticamente via sw.js a cada
startup. O papel deste updater é:
  1. Limpar o cache Redis da Evolution (prefixo evolution:*)
  2. Forçar restart do service no Swarm (--force), fazendo re-fetch da versão

Cron: 0 0 * * * (todo dia 00:00)
"""

import os
import subprocess
import sys
import logging
from datetime import datetime

# ── Config ────────────────────────────────────────────────────────────────────
EVOLUTION_SERVICE = os.getenv("EVOLUTION_SERVICE_NAME", "comms_evolution")
REDIS_CONTAINER   = os.getenv("REDIS_CONTAINER", "comms_redis")
REDIS_PREFIX      = os.getenv("CACHE_REDIS_PREFIX_KEY", "evolution")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger(__name__)


def flush_evolution_cache() -> bool:
    log.info(f"Limpando cache da Evolution (prefixo: {REDIS_PREFIX}:*)")
    try:
        find = subprocess.run(
            ["docker", "ps", "--filter", f"name={REDIS_CONTAINER}",
             "--format", "{{.ID}}"],
            capture_output=True, text=True,
        )
        container_id = find.stdout.strip().split("\n")[0]
        if not container_id:
            log.warning("Container Redis não encontrado. Pulando flush.")
            return True

        scan = subprocess.run(
            ["docker", "exec", container_id,
             "redis-cli", "--scan", "--pattern", f"{REDIS_PREFIX}:*"],
            capture_output=True, text=True,
        )
        keys = [k for k in scan.stdout.strip().split("\n") if k]

        if not keys:
            log.info("Nenhuma chave de cache encontrada.")
            return True

        subprocess.run(
            ["docker", "exec", container_id, "redis-cli", "DEL"] + keys,
            capture_output=True,
        )
        log.info(f"{len(keys)} chave(s) removida(s).")
        return True
    except Exception as e:
        log.warning(f"Erro ao limpar cache: {e}")
        return False


def restart_evolution_service() -> bool:
    """
    Força restart do service no Swarm.
    O Evolution v2.3.7+ faz fetch automático da versão WA via sw.js no startup.
    """
    log.info(f"Forçando restart de {EVOLUTION_SERVICE}…")
    result = subprocess.run(
        ["docker", "service", "update", "--force", EVOLUTION_SERVICE],
        capture_output=True, text=True,
    )
    if result.returncode == 0:
        log.info("Serviço reiniciado com sucesso.")
        return True
    log.error(f"Falha: {result.stderr} | {result.stdout}")
    return False


def main():
    log.info("=" * 60)
    log.info(f"WhatsApp Version Updater — {datetime.now()}")
    log.info("Evolution v2.3.7+: versão WA buscada automaticamente via sw.js no startup.")

    flush_evolution_cache()

    if not restart_evolution_service():
        sys.exit(1)

    log.info("Concluído — Evolution irá re-buscar a versão WA atual no próximo startup.")


if __name__ == "__main__":
    main()
