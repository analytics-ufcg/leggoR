#' @title Calcula o tamanho dos nós
#' @description Recebe um dataframe com as arestas e os nós, e calcula o tamanho do nó
#' a partir do somatório dos pesos das arestas
#' @param final_edges Dataframe com as arestas
#' @param final_nodes Dataframe com os nós
#' @param smoothing Variável para suavizar o tamanho dos nós
#' @return Dataframe dos nós com a coluna node_size
#' @export
compute_nodes_size <- function(final_edges, final_nodes, smoothing = 1) {
  final_edges <-
    final_edges %>%
    dplyr::mutate(value = dplyr::if_else(source == target, value/2, value))
  nodes_size_source <-
    final_edges %>%
    dplyr::group_by(node = source, id_leggo) %>%
    dplyr::summarise(node_size = sum(value)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(node = as.character(node))
  nodes_size_target <-
    final_edges %>%
    dplyr::group_by(node = target, id_leggo) %>%
    dplyr::summarise(node_size = sum(value)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(node = as.character(node))
  nodes_size <-
    dplyr:: bind_rows(nodes_size_source,nodes_size_target) %>%
    dplyr::group_by(node, id_leggo) %>%
    dplyr::summarise(node_size = sum(node_size)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(node = as.numeric(node))
  final_nodes %>%
    dplyr::left_join(nodes_size, by=c("id_autor"="node", "id_leggo")) %>%
    dplyr::mutate(node_size = node_size / smoothing)
}

#' @title Gera os dataframe de nós
#' @description Recebe um dataframe com coautorias e gera os dataframes com os nós
#' @param coautorias Dataframe com as coautorias
#' @return Dataframes de nós
#' @export
generate_nodes <- function(coautorias) {
  graph_nodes <-
      dplyr::bind_rows(
      coautorias %>% dplyr::select(id_autor = id_autor.x, nome = nome.x, partido = partido.x,
                                   uf = uf.x, bancada = bancada.x, casa_autor = casa_autor.x),
      coautorias %>% dplyr::select(id_autor = id_autor.y, nome = nome.y, partido = partido.y,
                                   uf = uf.y, bancada = bancada.y, casa_autor = casa_autor.y)) %>%
      dplyr::distinct()

  final_nodes <- graph_nodes %>%
    tibble::as_tibble() %>%
    dplyr::mutate(nome_eleitoral = purrr::pmap_chr(list(nome, partido, uf), ~ agoradigital::formata_nome_eleitoral(..1, ..2, ..3)))

  return(final_nodes)
}

#' @title Gera os dataframe de nós únicos
#' @description Remove os nós duplicados (eles estavam duplicados pois os nomes vinham
#' diferente)
#' @param coautorias Dataframe com as coautorias
#' @return Dataframes de nós
#' @export
get_unique_nodes <- function(coautorias) {
  nodes <-
    coautorias %>%
    dplyr::group_by(id_leggo) %>%
    dplyr::group_modify(~ agoradigital::generate_nodes(.), .keep = T) %>%
    dplyr::ungroup()

  unique_nodes <-
    nodes %>%
    dplyr::group_by(id_leggo, id_autor, casa_autor) %>%
    dplyr::summarise(nome = dplyr::first(nome),
                     partido = dplyr::first(partido),
                     uf = dplyr::first(uf),
                     bancada = dplyr::first(bancada),
                     nome_eleitoral = dplyr::first(nome_eleitoral))

  nodes %>%
    dplyr::inner_join(unique_nodes, by = c("id_leggo", "id_autor", "casa_autor", "nome", "partido",
                                           "uf", "bancada", "nome_eleitoral"))
}

#' @title Gera os dataframe de arestas
#' @description Recebe um dataframe com coautorias e gera os dataframes com as arestas
#' @param coautorias Dataframe com as coautorias
#' @param graph_nodes Dataframe com os nós
#' @param edges_weight Variável para multiplicar com os pesos das arestas
#' @return Dataframes de arestas
#' @export
generate_edges <- function(coautorias, graph_nodes, edges_weight = 1) {
  coautorias_index <-
    coautorias %>%
    dplyr::left_join(graph_nodes %>%  dplyr::select(id_autor), by=c("id_autor.x"="id_autor")) %>%
    dplyr::left_join(graph_nodes %>%  dplyr::select(id_autor), by=c("id_autor.y"="id_autor"))

  graph_edges <- coautorias_index %>%
    dplyr::select(
      source = id_autor.x,
      target = id_autor.y,
      value = peso_arestas)

  final_edges <- graph_edges %>%
    tibble::as_tibble() %>%
    dplyr::mutate(value = value*edges_weight) %>%
    dplyr::distinct()
}

#' @title Remove arestas duplicadas
#' @description Recebe um dataframe com autorias e remove as arestas
#' duplicadas
#' @param df Dataframe com as arestas duplicadas
#' @return Dataframe sem as duplicadas
remove_duplicated_edges <- function(df) {
  deduplicated_df <- df
  if(nrow(df) > 0) {
    deduplicated_df <- df %>%
      dplyr::mutate(col_pairs = dplyr::if_else(id_autor.x > id_autor.y,
                                               paste0(id_autor.y, ":", id_autor.x),
                                               paste0(id_autor.x, ":", id_autor.y))) %>%
      dplyr::distinct(id_leggo, id_documento, col_pairs, peso_arestas) %>%
      tidyr::separate(col = col_pairs,
                      c("id_autor.x",
                        "id_autor.y"),
                      sep = ":")
  }
  return(deduplicated_df)
}

#' @title Cria o dataframe de coautorias sem os dados de parlamentares
#' @description  Recebe o dataframe de autorias, pesos e o limiar e retorna o dataframe
#' de coautorias raw
#' @param autorias Dataframe com as autorias
#' @param limiar Peso mínimo das arestas
#' @param casa_origem Casa de origem dos documentos de autoria
#' @return Dataframe de coautorias para documentos de uma casa de origem.
get_coautorias_raw <- function(autorias, limiar, casa_origem) {
  # Filtra autorias apenas para casa de origem
  autorias <- autorias %>%
    dplyr::filter(casa == casa_origem)

  # Calcula o número de autores e o peso das arestas (filtra usando um limiar)
  num_autorias_por_pl <- autorias %>%
    dplyr::group_by(id_leggo, id_documento) %>%
    dplyr::summarise(num_autores = dplyr::n_distinct(id_autor),
                     peso_arestas = 1/dplyr::n_distinct(id_autor)) %>%
    dplyr::ungroup() %>%
    dplyr::filter(peso_arestas >= limiar)

  # Obtem informações dos documentos
  coautorias_raw_info <- autorias %>%
    dplyr::distinct(id_leggo, id_principal, casa, id_documento, data)

  # Garbage collection
  gc()

  # Gera dataframe de coautorias
  coautorias_raw <- autorias %>%
    dplyr::select(id_leggo, id_documento, id_autor) %>%
    dplyr::full_join(autorias %>%
                       dplyr::select(id_leggo, id_documento, id_autor),
                     by = c("id_leggo", "id_documento"))
  gc()

  coautorias_simples <- coautorias_raw %>%
    dplyr::inner_join(num_autorias_por_pl %>% dplyr::filter(num_autores == 1),
                      by=c("id_documento", "id_leggo"))

  coautorias_multiplas <- coautorias_raw %>%
    dplyr::inner_join(num_autorias_por_pl %>% dplyr::filter(num_autores > 1),
                      by=c("id_documento", "id_leggo")) %>%
    dplyr::filter(id_autor.x != id_autor.y)

  # Remove dataframe não mais usado e chama garbage collector.
  rm(coautorias_raw)
  gc()

  coautorias <- dplyr::bind_rows(coautorias_simples, coautorias_multiplas) %>%
    dplyr::select(-num_autores) %>%
    dplyr::distinct()

  # Remove dataframe não mais utilizado
  rm(coautorias_multiplas)
  gc()

  # Remove arestas duplicadas, cruza com informações dos documentos e calcula peso final para as arestas
  coautorias %>%
    remove_duplicated_edges() %>%
    dplyr::left_join(coautorias_raw_info,
                     by = c("id_leggo", "id_documento")) %>%
    dplyr::group_by(id_leggo, id_principal, casa, id_autor.x, id_autor.y) %>%
    dplyr::summarise(peso_arestas = sum(peso_arestas),
                     num_coautorias = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(id_autor.x = as.numeric(id_autor.x),
                  id_autor.y = as.numeric(id_autor.y))
}

#' @title Cria o dataframe de coautorias
#' @description  Recebe o dataframe de documentos, autores a casa e o limiar
#' e retorna o dataframe de coautorias
#' @param docs Dataframe com os documentos
#' @param autores Dataframe com autores dos documentos
#' @param casa camara ou senado
#' @param limiar Peso mínimo das arestas
#' @param partidos_oposicao lista com os partidos da oposição
#' @param data_inicial Data inicial para considerar coautorias
#' @return Dataframe
#' @export
get_coautorias <- function(docs, autores, casa, limiar = 0.1, partidos_oposicao, data_inicial = NULL) {
  autorias <- tibble::tibble()
  coautorias <- tibble::tibble()

  if (casa == 'camara') {
    autorias <- agoradigital::prepare_autorias_df_camara(docs, autores)
  } else {
    autorias <- agoradigital::prepare_autorias_df_senado(docs, autores)
    autores <- autores %>%
      rename(nome = nome_autor)
  }

  parlamentares <- autores %>%
    mutate(casa_autor = if_else(tolower(tipo_autor) == "deputado",
                                "camara",
                                "senado")) %>%
    dplyr::group_by(id_autor) %>%
    dplyr::summarise(nome = dplyr::first(nome),

              partido = dplyr::last(partido),
              uf = dplyr::first(uf),
              casa_autor = dplyr::first(casa_autor)) %>%
    dplyr::ungroup()

  ## Filtra autorias passadas como parâmetro para coautorias com base na data_inicial
  if (!is.null(data_inicial)) {
    autorias_filtradas <- autorias %>%
      dplyr::filter(data > data_inicial)
  } else {
    autorias_filtradas <- autorias
  }

  coautorias <- get_coautorias_raw(autorias_filtradas, limiar, casa)

  if (nrow(coautorias) > 0) {
    autorias <-
      autorias %>%
      dplyr::left_join(parlamentares, by = "id_autor") %>%
      dplyr::distinct() %>%
      dplyr::mutate(nome_eleitoral = purrr::pmap_chr(list(nome, partido, uf),
                                                     ~ agoradigital::formata_nome_eleitoral(..1, ..2, ..3))) %>%
      dplyr::select(-c(nome, partido, uf))

    parlamentares <-
      parlamentares %>%
      dplyr::mutate(bancada = dplyr::if_else(partido %in% partidos_oposicao, "oposição", "governo"))

    coautorias <-
      coautorias %>%
      dplyr::inner_join(parlamentares, by = c("id_autor.x" = "id_autor")) %>%
      dplyr::inner_join(parlamentares, by = c("id_autor.y" = "id_autor")) %>%
      dplyr::distinct()
  } else {
    autorias <- tibble::tibble()
  }

  return(list(coautorias = coautorias, autorias = autorias))
}

#' @title Cria o dataframe de autorias da camara
#' @description Faz um merge do df de documentos com autores
#' @param docs_camara Dataframe com documentos da camara
#' @param autores_camara Dataframe com autores da camara
#' @return Dataframe
#' @export
prepare_autorias_df_camara <- function(docs_camara, autores_camara) {
  autores_docs <-
    merge(docs_camara,
          autores_camara,
          by = c("id_principal", "id_documento", "casa")) %>%
    dplyr::mutate(tipo_documento_ext = descricao_tipo_documento) %>% ## padroniza com dataframe do senado
    dplyr::group_by(id_principal, casa, id_documento) %>%
    dplyr::mutate(peso_autor_documento = 1/dplyr::n_distinct(id_autor)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(sigla = stringr::str_glue("{sigla_tipo} {numero}/{ano}")) %>%
    dplyr::select(
      id_principal,
      casa,
      id_documento,
      sigla,
      descricao_tipo_documento,
      tipo_documento_ext,
      id_autor,
      data,
      url_inteiro_teor,
      id_leggo,
      peso_autor_documento
    ) %>%
    dplyr::distinct()
}

#' @title Cria o dataframe de autorias da senado
#' @description Faz um merge do df de documentos com autores
#' @param docs_senado Dataframe com documentos da senado
#' @param autores_senado Dataframe com autores da senado
#' @return Dataframe
#' @export
prepare_autorias_df_senado <- function(docs_senado, autores_senado) {
  autores_docs <-
    merge(
      docs_senado,
      autores_senado %>% dplyr::filter(!is.na(id_autor)),
      by = c("id_principal", "id_documento", "casa")
    ) %>%
    dplyr::group_by(id_principal, casa, id_documento) %>%
    dplyr::mutate(peso_autor_documento = 1 / dplyr::n_distinct(id_autor)) %>%
    dplyr::ungroup() %>%
    dplyr::select(
      id_principal,
      casa,
      id_documento,
      sigla = descricao_identificacao_materia,
      descricao_tipo_documento = descricao_texto,
      tipo_documento_ext = descricao_tipo_texto,
      id_autor,
      data,
      url_inteiro_teor = url_texto,
      id_leggo,
      peso_autor_documento
    ) %>%
    dplyr::distinct()
}

#' @title Cria o dataframe com os pesos das autorias
#' @description Calcula o peso de cada autoria e o peso é menor quanto
#' maior o número de autores
#' @param autorias Dataframe com as autorias
#' @return Dataframe
#' @export
compute_peso_autoria_doc <- function(autorias) {
  peso_autorias <- autorias %>%
    dplyr::group_by(id_principal, id_documento) %>%
    dplyr::summarise(peso_arestas = 1/dplyr::n())
}
