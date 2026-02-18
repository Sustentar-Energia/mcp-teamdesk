"""
Servidor MCP para integração com TeamDesk API
ForGreen Database - ID: 101885
"""

import json
import os
import urllib.request
import urllib.parse
import urllib.error
from typing import Any
from mcp.server.fastmcp import FastMCP

# Configurações do TeamDesk
_api_token = os.getenv("TEAMDESK_API_TOKEN", "")
_database_id = os.getenv("TEAMDESK_DATABASE_ID", "101885")

if not _api_token:
    import sys
    print("ERRO: Variável de ambiente TEAMDESK_API_TOKEN não definida.", file=sys.stderr)
    print("Configure via Claude Desktop (env) ou exporte antes de rodar.", file=sys.stderr)
    sys.exit(1)

TEAMDESK_CONFIG = {
    "base_url": "https://www.teamdesk.net/secure/api/v2",
    "database_id": _database_id,
    "api_token": _api_token
}

# Inicializa o servidor MCP
mcp = FastMCP("TeamDesk ForGreen")


def make_request(endpoint: str, method: str = "GET", data: dict = None) -> dict:
    """Faz uma requisição à API do TeamDesk."""
    url = f"{TEAMDESK_CONFIG['base_url']}/{TEAMDESK_CONFIG['database_id']}/{endpoint}"

    headers = {
        "Authorization": f"Bearer {TEAMDESK_CONFIG['api_token']}",
        "Content-Type": "application/json"
    }

    req_data = None
    if data:
        req_data = json.dumps(data).encode('utf-8')

    request = urllib.request.Request(url, data=req_data, headers=headers, method=method)

    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return {"error": f"HTTP {e.code}: {error_body}"}
    except Exception as e:
        return {"error": str(e)}


@mcp.tool()
def list_tables() -> str:
    """
    Lista todas as tabelas disponíveis no banco de dados ForGreen.
    Retorna o nome e ID de cada tabela.
    """
    result = make_request("describe.json")

    if "error" in result:
        return f"Erro: {result['error']}"

    tables = []
    for table in result.get("tables", []):
        tables.append({
            "id": table["id"],
            "nome": table["recordName"],
            "nome_plural": table["recordsName"]
        })

    return json.dumps(tables, indent=2, ensure_ascii=False)


@mcp.tool()
def describe_table(table_name: str) -> str:
    """
    Descreve a estrutura de uma tabela específica.
    Retorna os campos, tipos e propriedades da tabela.

    Args:
        table_name: Nome da tabela (ex: "Usina Solar", "Cliente", "Faturamento")
    """
    encoded_name = urllib.parse.quote(table_name)
    result = make_request(f"{encoded_name}/describe.json")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def select_data(
    table_name: str,
    columns: str = None,
    filter_expr: str = None,
    sort: str = None,
    top: int = 100,
    skip: int = 0
) -> str:
    """
    Consulta dados de uma tabela do TeamDesk.

    Args:
        table_name: Nome da tabela (ex: "Usina Solar", "Cliente")
        columns: Colunas a retornar, separadas por vírgula (opcional, retorna todas se vazio)
        filter_expr: Expressão de filtro TeamDesk (ex: "[Status] = 'Ativo'")
        sort: Ordenação (ex: "Nome" ou "-Data" para decrescente)
        top: Número máximo de registros (padrão: 100, máximo: 500)
        skip: Registros a pular para paginação (padrão: 0)
    """
    encoded_name = urllib.parse.quote(table_name)

    params = {"top": min(top, 500), "skip": skip}

    if columns:
        params["column"] = columns.split(",")
    if filter_expr:
        params["filter"] = filter_expr
    if sort:
        params["sort"] = sort

    query_string = urllib.parse.urlencode(params, doseq=True)
    result = make_request(f"{encoded_name}/select.json?{query_string}")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def select_view(table_name: str, view_name: str, top: int = 100, skip: int = 0) -> str:
    """
    Consulta dados de uma View específica no TeamDesk.

    Args:
        table_name: Nome da tabela
        view_name: Nome da view (ex: "Default View", "Ativos")
        top: Número máximo de registros (padrão: 100)
        skip: Registros a pular para paginação
    """
    encoded_table = urllib.parse.quote(table_name)
    encoded_view = urllib.parse.quote(view_name)

    params = {"top": min(top, 500), "skip": skip}
    query_string = urllib.parse.urlencode(params)

    result = make_request(f"{encoded_table}/{encoded_view}/select.json?{query_string}")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def get_record(table_name: str, record_id: int) -> str:
    """
    Recupera um registro específico pelo ID.

    Args:
        table_name: Nome da tabela
        record_id: ID do registro
    """
    encoded_name = urllib.parse.quote(table_name)
    result = make_request(f"{encoded_name}/{record_id}.json")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def create_record(table_name: str, data: str) -> str:
    """
    Cria um novo registro em uma tabela.

    Args:
        table_name: Nome da tabela
        data: Dados do registro em formato JSON (ex: '{"Nome": "Teste", "Status": "Ativo"}')
    """
    encoded_name = urllib.parse.quote(table_name)

    try:
        record_data = json.loads(data)
    except json.JSONDecodeError as e:
        return f"Erro: JSON inválido - {e}"

    result = make_request(f"{encoded_name}/create.json", method="POST", data=[record_data])

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def update_record(table_name: str, record_id: int, data: str) -> str:
    """
    Atualiza um registro existente.

    Args:
        table_name: Nome da tabela
        record_id: ID do registro a atualizar
        data: Dados a atualizar em formato JSON (ex: '{"Status": "Inativo"}')
    """
    encoded_name = urllib.parse.quote(table_name)

    try:
        record_data = json.loads(data)
        record_data["@row.id"] = record_id
    except json.JSONDecodeError as e:
        return f"Erro: JSON inválido - {e}"

    result = make_request(f"{encoded_name}/update.json", method="POST", data=[record_data])

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def delete_record(table_name: str, record_id: int) -> str:
    """
    Deleta um registro de uma tabela.

    Args:
        table_name: Nome da tabela
        record_id: ID do registro a deletar
    """
    encoded_name = urllib.parse.quote(table_name)
    result = make_request(f"{encoded_name}/delete.json?id={record_id}")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps({"success": True, "deleted_id": record_id}, indent=2)


@mcp.tool()
def search_records(table_name: str, search_text: str, columns: str = None, top: int = 50) -> str:
    """
    Busca registros que contenham o texto especificado.

    Args:
        table_name: Nome da tabela
        search_text: Texto a buscar
        columns: Colunas onde buscar, separadas por vírgula (opcional)
        top: Máximo de resultados (padrão: 50)
    """
    encoded_name = urllib.parse.quote(table_name)

    # Constrói filtro de busca
    filter_expr = f"Contains([*], '{search_text}')"

    params = {"top": min(top, 500), "filter": filter_expr}
    if columns:
        params["column"] = columns.split(",")

    query_string = urllib.parse.urlencode(params, doseq=True)
    result = make_request(f"{encoded_name}/select.json?{query_string}")

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def upsert_records(table_name: str, match_column: str, data: str) -> str:
    """
    Insere ou atualiza registros (upsert) em uma tabela.
    Se o registro com o valor do match_column já existir, atualiza. Senão, cria.

    Args:
        table_name: Nome da tabela
        match_column: Nome da coluna usada para match (ex: "Chave_Unica")
        data: JSON array de registros (ex: '[{"Nome": "X", "Valor": 1}]')
    """
    encoded_name = urllib.parse.quote(table_name)
    encoded_match = urllib.parse.quote(match_column)

    try:
        records = json.loads(data)
        if not isinstance(records, list):
            records = [records]
    except json.JSONDecodeError as e:
        return f"Erro: JSON inválido - {e}"

    result = make_request(
        f"{encoded_name}/upsert.json?match={encoded_match}",
        method="POST",
        data=records
    )

    if "error" in result:
        return f"Erro: {result['error']}"

    return json.dumps(result, indent=2, ensure_ascii=False)


@mcp.tool()
def gerar_documento(table_name: str, document_name: str, record_id: int, output_path: str = None) -> str:
    """
    Gera um documento Word (DOCX) a partir de um template TeamDesk Documents.
    Usa a API de Mail Merge do TeamDesk para preencher MERGEFIELDs com dados do registro.

    Args:
        table_name: Nome da tabela (ex: "Relatório O&M")
        document_name: Nome do documento/template no TeamDesk (ex: "Relatório Word")
        record_id: ID do registro para preencher o template
        output_path: Caminho para salvar o arquivo (opcional, usa pasta Downloads se vazio)
    """
    encoded_table = urllib.parse.quote(table_name)
    encoded_doc = urllib.parse.quote(document_name)

    url = (
        f"{TEAMDESK_CONFIG['base_url']}/{TEAMDESK_CONFIG['database_id']}"
        f"/{encoded_table}/{encoded_doc}/document.json?id={record_id}"
    )

    headers = {
        "Authorization": f"Bearer {TEAMDESK_CONFIG['api_token']}",
    }

    request = urllib.request.Request(url, headers=headers, method="GET")

    try:
        with urllib.request.urlopen(request) as response:
            content = response.read()
            content_type = response.headers.get("Content-Type", "")

            # Se retornou JSON, provavelmente é um erro
            if "application/json" in content_type:
                error_data = json.loads(content.decode('utf-8'))
                return f"Erro: {json.dumps(error_data, ensure_ascii=False)}"

            # Determinar caminho de saída
            if not output_path:
                downloads = os.path.expanduser("~/Downloads")
                os.makedirs(downloads, exist_ok=True)
                output_path = os.path.join(downloads, f"documento_{record_id}.docx")

            # Salvar arquivo
            with open(output_path, "wb") as f:
                f.write(content)

            return json.dumps({
                "success": True,
                "record_id": record_id,
                "output_path": output_path,
                "size_bytes": len(content)
            }, indent=2, ensure_ascii=False)

    except urllib.error.HTTPError as e:
        error_body = e.read().decode('utf-8') if e.fp else str(e)
        return f"Erro HTTP {e.code}: {error_body}"
    except Exception as e:
        return f"Erro: {str(e)}"


if __name__ == "__main__":
    mcp.run()
