#!/usr/bin/env bash
# Copia o código do iPhone (só o que está no git, da branch atual) para a pasta iphone/ do repositório
# público das releases (arthurleticiaclaude/ufac-no-bolso). Não faz commit nem push: confira e envie à mão.
#
# Uso: ios-pwa/tools/publicar-codigo.sh /caminho/do/clone/ufac-no-bolso
#
# - Vai só o que está commitado: .env.production, .dev.vars, builds e node_modules ficam de fora.
# - As fixtures anonimizadas (da raiz do projeto, usadas pelos testes) vão para iphone/fixtures, e os dois
#   caminhos que apontam para elas são ajustados, para os testes rodarem dentro do repositório público.
set -euo pipefail

destino="${1:?informe o clone do ufac-no-bolso}"
raiz="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
alvo="$destino/iphone"

rm -rf "$alvo"
mkdir -p "$alvo"
git -C "$raiz" archive HEAD ios-pwa | tar -x -C "$alvo" --strip-components=1
git -C "$raiz" archive HEAD fixtures | tar -x -C "$alvo"
rm -rf "$alvo/fixtures/raw" # por garantia: dados reais nunca saem daqui

# Caminhos das fixtures: na raiz do projeto privado ficam dois níveis acima; aqui, dentro de iphone/.
sed -i.bak "s#'../../fixtures'#'../fixtures'#" "$alvo/e2e/worker-falso.mjs"
sed -i.bak 's#"../../../fixtures"#"../../fixtures"#' "$alvo/web/test/extratores.test.js"
find "$alvo" -name '*.bak' -delete

commit="$(git -C "$raiz" rev-parse --short HEAD)"
echo "Copiado de ios-pwa@$commit para $alvo"
