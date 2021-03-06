source(here::here("R/utils.R"))
camara_env <- jsonlite::fromJSON(here::here("R/config/environment_camara.json"))
senado_env <- jsonlite::fromJSON(here::here("R/config/environment_senado.json"))

#' @title Importa as informações de uma proposição da internet.
#' @description Recebido um id e a casa, a função roda os scripts para
#' importar os dados daquela proposição.
#' @param prop_id Identificador da proposição que pode ser recuperado no site da casa legislativa.
#' @param casa Casa onde o projeto está tramitando
#' @param out_folderpath Caminho da pasta onde os dados devem ser salvos
#' @param apelido Apelido da proposição
#' @param tema Tema da proposição
#' @export
#' @examples
#' import_proposicao(129808, 'senado', 'Cadastro Positivo', 'Agenda Nacional', 'data/')
import_proposicao <- function(prop_id, casa, apelido, tema, out_folderpath=NULL) {
  casa <- tolower(casa)
  if (!(casa %in% c('camara','senado'))) {
    return('Parâmetro "casa" não identificado.')
  }

  prop_df <- fetch_proposicao(prop_id,casa,apelido, tema)
  tram_df <- fetch_tramitacao(prop_id,casa)
  emendas_df <- rcongresso::fetch_emendas(prop_id,casa)

  if (!is.null(out_folderpath)) {
    if (!is.null(prop_df)) readr::write_csv(prop_df, build_data_filepath(out_folderpath,'proposicao',casa,prop_id))
    if (!is.null(tram_df)) readr::write_csv(tram_df, build_data_filepath(out_folderpath,'tramitacao',casa,prop_id))
    if (!is.null(emendas_df)) readr::write_csv(emendas_df, build_data_filepath(out_folderpath,'emendas',casa,prop_id))
  }

  return(list(proposicao = prop_df, tramitacao = tram_df))
}
#' @title Recupera os detalhes de uma proposição no Senado ou na Câmara
#' @description Retorna dataframe com os dados detalhados da proposição, incluindo número, ementa, tipo e data de apresentação.
#' @param id ID de uma proposição
#' @param casa casa de onde a proposição esta
#' @param apelido Apelido da proposição
#' @param tema Tema da proposição
#' @param retry Flag indicando se é necessário tentar novamente ao se deparar com erro.
#' @return Dataframe com as informações detalhadas de uma proposição
#' @examples
#' fetch_proposicao(129808, 'senado', 'Cadastro Positivo', 'Agenda Nacional', F)
#' @export
fetch_proposicao <- function(id, casa, apelido="", tema="", retry=FALSE) {
  casa <- tolower(casa)
  if (casa == "camara") {
    fetch_proposicao_camara(id, apelido, tema)
  } else if (casa == "senado") {
    fetch_proposicao_senado(id, apelido, tema, retry)
  } else {
    return("Parâmetro 'casa' não identificado.")
  }
}

#' @title Recupera os detalhes de proposições no Senado ou na Câmara
#' @description Retorna dataframe com os dados detalhados das proposições, incluindo número, ementa, tipo e data de apresentação.
#' @param pls_ids Dataframe com id e casa das proposições
#' @return Dataframe com as informações detalhadas das proposições
#' @examples
#' all_pls <- readr::read_csv('data/tabela_geral_ids_casa.csv')
#' fetch_proposicoes(all_pls)
#' @export
fetch_proposicoes <- function(pls_ids) {
  purrr::map2_df(pls_ids$id, pls_ids$casa, ~ fetch_proposicao(.x, .y))
}

#' @title Recupera os detalhes de uma proposição no Senado
#' @description Retorna dataframe com os dados detalhados da proposição, incluindo número, ementa, tipo e data de apresentação.
#' Ao fim, a função retira todos as colunas que tenham tipo lista para uniformizar o dataframe.
#' @param proposicao_id ID de uma proposição do Senado
#' @param normalized whether or not the output dataframe should be normalized (have the same format and column names for every house)
#' @param apelido apelido da proposição
#' @param tema tema da proposição
#' @param retry Flag indicando se é necessário tentar novamente caso dê erro
#' @return Dataframe com as informações detalhadas de uma proposição no Senado
#' @examples
#' fetch_proposicao_senado(91341, 'Cadastro Positivo', 'Agenda Nacional')
fetch_proposicao_senado <- function(id, apelido, tema, retry=FALSE) {
  proposicao <- NULL
  if (retry) {
    count <- 0
    while (is.null(proposicao) && count < 5) {
      cat(
        paste(
          "\n--- Tentativa",
          count + 1,
          "de gerar dados de proposições para a proposição",
          id,
          "\n"
        )
      )
      try(proposicao <- rcongresso::fetch_proposicao_senado(id))
      count <- count + 1
    }
  } else {
    proposicao <- rcongresso::fetch_proposicao_senado(id)
  }

  if (!is.null(proposicao)) {
    proposicao <- proposicao %>%
      dplyr::transmute(
        prop_id = as.integer(codigo_materia),
        sigla_tipo = sigla_subtipo_materia,
        numero = as.integer(numero_materia),
        ano = as.integer(ano_materia),
        ementa = ementa_materia,
        data_apresentacao = lubridate::ymd_hm(paste(data_apresentacao, "00:00")),
        casa = "senado",
        casa_origem = ifelse(
          tolower(nome_casa_origem) == "senado federal",
          "senado",
          "camara"
        ),
        sigla_ultimo_local = sigla_local,
        sigla_casa_ultimo_local = sigla_casa_local,
        nome_ultimo_local = nome_local,
        data_ultima_situacao = data_situacao,
        uri_prop_principal = ifelse(!"uri_prop_principal" %in% names(.),
                                    NA_character_,
                                    uri_prop_principal),
        apelido_materia = ifelse(
          "apelido_materia" %in% names(.),
          apelido_materia,
          apelido),
        tema = tema)
  } else {
    proposicao <- tibble::tibble(
      prop_id = integer(),
      sigla_tipo = character(),
      numero = integer(),
      ano = integer(),
      ementa = character(),
      data_apresentacao = character(),
      casa = character(),
      casa_origem = character(),
      sigla_ultimo_local = character(),
      sigla_casa_ultimo_local = character(),
      nome_ultimo_local = character(),
      data_ultima_situacao = character(),
      apelido_materia = character(),
      tema= character())
  }

  return(proposicao)
}

#' @title Baixa dados sobre uma proposição
#' @description Retorna um dataframe contendo dados sobre uma proposição
#' @param prop_id Um ou mais IDs de proposições
#' @param normalized whether or not the output dataframe should be normalized (have the same format and column names for every house)
#' @param apelido Apelido da proposição
#' @param tema Tema da proposição
#' @return Dataframe
#' @examples
#' fetch_proposicao_camara(2056568, "Lei para acabar zona de amortecimento", "Meio Ambiente")
fetch_proposicao_camara <- function(id, apelido, tema) {

  fetch_autor_camara_safely <-
    purrr::safely(function(id) {
      rcongresso::fetch_autor_camara(id)
    },
    otherwise = tibble::tribble( ~ nome,
                                 ~ codTipo))

  autor_df <- fetch_autor_camara_safely(id)$result

  if("ultimoStatus.nomeEleitoral" %in% names(autor_df)) {
    autor_df %<>%
      dplyr::rename('nome' = 'ultimoStatus.nomeEleitoral')
  }

  proposicao <- rcongresso::fetch_proposicao_camara(id) %>%
    rename_df_columns() %>%
    dplyr::transmute(prop_id = as.integer(id),
                     sigla_tipo,
                     numero = as.integer(numero),
                     ano = as.integer(ano),
                     ementa = paste(ementa,ementa_detalhada),
                     data_apresentacao = lubridate::ymd_hm(stringr::str_replace(data_apresentacao,'T',' ')),
                     casa = 'camara',
                     casa_origem =
                       ifelse(
                         nrow(autor_df) == 0,
                         NA,
                         ifelse(
                           autor_df %>% head(1) %>%
                             dplyr::select(codTipo) == 40000,
                           "senado",
                           "camara"
                         )
                       ),
                     sigla_ultimo_local = status_proposicao_sigla_orgao,
                     sigla_casa_ultimo_local = "camara",
                     nome_ultimo_local = NA_character_,
                     data_ultima_situacao = status_proposicao_data_hora,
                     uri_prop_principal = ifelse(!"uri_prop_principal" %in% names(.),
                                                         NA_character_,
                                                         uri_prop_principal),
                     apelido_materia = as.character(apelido),
                     tema = tema)
  proposicao
}

#' @title Baixa os ids dos documentos a partir dos ids das principais, verificando quais delas são novas
#' @description Retorna um dataframe contendo os novos documentos
#' @param all_pls_ids IDs das proposições principais
#' @param current_docs_ids IDs dos documentos atualmente baixados
#' @param casa_prop Casa de origem dos documentos
#' @return Dataframe
#' @export
find_new_documentos <- function(all_pls_ids, current_docs_ids, casa_prop) {

  new_docs_ids <- tibble::tibble()

  pls_principais_ids <- all_pls_ids %>%
    dplyr::filter(casa == casa_prop) %>%
    dplyr::select(id_principal,
                  casa) %>%
    dplyr::mutate(id_documento = id_principal)

  if (nrow(pls_principais_ids) > 0) {
    all_docs_ids <- purrr::map2_df(pls_principais_ids$id_principal,
                                   pls_principais_ids$casa,
                                   ~rcongresso::fetch_ids_relacionadas(.x, .y)) %>%
      dplyr::rename(id_principal = id_prop,
                    id_documento = id_relacionada)  %>%
      dplyr::mutate(id_principal = as.double(id_principal),
                    id_documento = as.double(id_documento)) %>%
      dplyr::bind_rows(pls_principais_ids)

    new_docs_ids <- all_docs_ids %>%
      dplyr::anti_join(current_docs_ids, by=c("id_documento","id_principal","casa"))
  }

  return(new_docs_ids)
}

#' @title Baixa autores de documentos, adequando as colunas ao padrão desejado
#' @description Retorna um dataframe contendo autores dos documentos
#' @param docs_data_df Dataframe com os dados dos documentos a serem baixadas
#' @return Dataframe
#' @export
fetch_autores_documentos <- function(docs_data_df) {
  casa_prop <- docs_data_df$casa[1]
  autores_docs <- purrr::pmap_df(list(docs_data_df$id_documento, docs_data_df$casa,
                                      docs_data_df$sigla_tipo), function(a,b,c) fetch_autores_documento(a,b,c)) %>%
    dplyr::mutate(casa = casa_prop) %>%
    rename_table_to_underscore()

  formatted_atores_df <- tibble::tibble()
  if (nrow(autores_docs) > 0) {
    if (casa_prop == 'camara') {
      formatted_atores_df <- autores_docs %>%
        dplyr::distinct() %>%
        dplyr::select(id_autor,
                      nome,
                      tipo_autor = tipo,
                      uri_autor = uri,
                      id_documento,
                      casa,
                      cod_tipo_autor = cod_tipo,
                      dplyr::everything())
    } else if (casa_prop == 'senado') {
      formatted_atores_df <- autores_docs %>%
        dplyr::distinct() %>%
        dplyr::select(id_autor = id_parlamentar,
                      nome,
                      tipo_autor = descricao_tipo_autor,
                      uri_autor = url_pagina,
                      id_documento,
                      casa,
                      partido = sigla_partido,
                      uf = uf_parlamentar,
                      dplyr::everything())
    } else {
      warning('Casa inválida')
    }
  }

  formatted_atores_df
}

#' @title Baixa dados dos documentos, adequando as colunas ao padrão desejado
#' @description Retorna um dataframe contendo dados dos documentos
#' @param docs_ids Dataframe com os IDs dos documentos a serem baixados
#' @return Dataframe
#' @examples
#' \dontrun{
#'   docs_data <- fetch_docs_data(2056568)
#' }
#' @export
fetch_documentos_data <- function(docs_ids) {
  docs <- purrr::map2_df(docs_ids$id_documento, docs_ids$casa, ~ fetch_documento(.x, .y)) %>%
    rename_table_to_underscore()
  formatted_docs_df <- tibble::tibble()
  casa <- docs_ids$casa[1]
  if (nrow(docs) > 0) {
    if (casa == 'camara') {
      formatted_docs_df <- merge(docs_ids, docs, by.x="id_documento", by.y = "id") %>%
        dplyr::distinct() %>%
        dplyr::select(id_documento,
                      id_principal,
                      casa,
                      sigla_tipo,
                      numero,
                      ano,
                      data_apresentacao,
                      ementa,
                      descricao_tipo_documento = descricao_tipo,
                      cod_tipo_documento = cod_tipo,
                      uri_documento = uri,
                      dplyr::everything())
    } else if (casa == 'senado') {
      formatted_docs_df <- merge(docs_ids, docs, by.x="id_documento", by.y = "codigo_materia") %>%
        dplyr::distinct() %>%
        dplyr::select(id_documento,
                      id_principal,
                      casa,
                      sigla_tipo = sigla_subtipo_materia,
                      numero = numero_materia,
                      ano = ano_materia,
                      data_apresentacao,
                      ementa = ementa_materia,
                      dplyr::everything())

    } else {
      warning('Casa inválida')
    }

  }
  return(formatted_docs_df)
}

#' @title Baixa dados dos documentos, através de um scrap
#' @description Retorna um dataframe contendo dados dos documentos
#' @param pls_ids Dataframe com os IDs das proposições cujos documentos
#' iremos baixar, formato (id_principal, casa)
#' @return Dataframe
#' @export
fetch_documentos_relacionados_senado <- function(pls_ids) {
  docs <-
    purrr::map_df(pls_ids$id_principal, ~ rcongresso::fetch_textos_proposicao_senado(.x))
  return(docs)
}

#' @title Extrai dos autores de documentos o partido, estado e nome
#' @description Recebe uma lista de autores e retorna um dataframe com
#' nome, partido e estado dos autores
#' @param autor_raw lista com autores
#' @param id_doc id do documento
#' @return Dataframe
extract_autor_relacionadas_senado <- function(autor_raw, id_doc) {
  stringr::str_split(autor_raw,",") %>%
    purrr::pluck(1) %>%
    purrr::map_df(.aux_extract_autor_relacionadas_senado) %>%
    dplyr::mutate(codigo_texto = id_doc) %>%
    dplyr::distinct()
}

#' @title Recebe uma string com o autor e quebra ela em nome, partido e estado
#' @description Recebe uma string com o autor e quebra ela em nome, partido e estado
#' @param autores_raw_element Autor
#' @return Dataframe
.aux_extract_autor_relacionadas_senado <- function(autores_raw_element) {
  clean_autor_raw = trimws(autores_raw_element)
  clean_autor_raw = stringr::str_replace(clean_autor_raw, "S/Partido","")
  nome_autor = ifelse(grepl('\\(',clean_autor_raw),stringr::str_extract(clean_autor_raw,"(.*?)(?=\\()"),clean_autor_raw)
  partido = stringr::str_extract(clean_autor_raw,"(?<=\\()(.*?)(?=\\/)")
  uf = stringr::str_extract(clean_autor_raw,"(?<=\\/)(.*?)(?=\\))")

  tibble::tibble(nome_autor = nome_autor, partido = partido, uf = uf)
}

#' @title Baixa dados dos autores dos documentos
#' @description Retorna um dataframe contendo dados dos autores dos documentos
#' @param relacionadas_docs Dataframe com os documetos oriundos do scrap
#' @return Dataframe
#' @export
fetch_autores_relacionadas_senado <- function(relacionadas_docs) {
  autores_raw <-
    relacionadas_docs %>%
    dplyr::rename(autor_raw = autoria_texto) %>%
    dplyr::filter(autor_raw != "Autoria não registrada.") %>%
    dplyr::mutate(autor_raw =
                    dplyr::if_else(stringr::str_detect(autor_raw,"Comissão de Constituição, Justiça e Cidadania"),
                                   stringr::str_replace_all(autor_raw, "Comissão de Constituição, Justiça e Cidadania",
                                                            "Comissão de Constituição Justiça e Cidadania"), autor_raw)) %>%
    dplyr::mutate(autor_raw =
                    dplyr::if_else(stringr::str_detect(autor_raw, "Comissão Mista da Medida Provisória .*"),
                                   stringr::str_replace_all(autor_raw, "Comissão Mista da Medida Provisória .*",
                                                            "Comissão Mista"), autor_raw)) %>%
    dplyr::select(codigo_materia, codigo_texto, casa, autor_raw)

  autores_metadata <-
    purrr::map2_df(autores_raw$autor_raw,
                   autores_raw$codigo_texto,
                   ~extract_autor_relacionadas_senado(.x, .y))

  autores <-
    autores_raw %>%
    dplyr::inner_join(autores_metadata, by="codigo_texto") %>%
    dplyr::select(-autor_raw) %>%
    unique()
}

#' @title Agrupa os tipos dos documentos
#' @description Retorna um dataframe contendo dados dos documentos
#' com uma coluna a mais (tipo de ação)
#' @param docs_data Dataframe com os todos os dados dos documentos
#' @return Dataframe
#' @export
add_tipo_evento_documento <- function(docs_data, documentos_scrap = F) {
  casa_prop <- docs_data$casa[1]
  docs <- tibble::tibble()
  if(documentos_scrap) {
    docs <- docs_data %>%
      fuzzyjoin::regex_left_join(senado_env$tipos_documentos_scrap, by = c(identificacao = "regex"), ignore_case = T) %>%
      dplyr::select(-regex) %>%
      dplyr::mutate(tipo = dplyr::if_else(is.na(tipo), "Outros", tipo),
                    tipo_acao = dplyr::if_else(is.na(tipo_acao), "Outros", tipo_acao))
  }else {
    if (casa_prop == 'camara') {
      docs <- docs_data %>%
        fuzzyjoin::regex_left_join(camara_env$tipos_documentos, by = c(descricao_tipo_documento = "regex"), ignore_case = T) %>%
        dplyr::mutate(tipo = dplyr::if_else(is.na(tipo), "Outros", tipo),
                      peso = dplyr::if_else(is.na(peso), 0, as.numeric(peso)),
                      tipo_acao = dplyr::if_else(is.na(tipo_acao), "Outros", tipo_acao)) %>%
        dplyr::group_by(id_principal, casa, id_documento, id_autor) %>%
        mutate(max_peso = max(peso)) %>%
        dplyr::ungroup() %>%
        filter(peso == max_peso) %>%
        dplyr::select(-regex, -peso, -max_peso)

    } else if (casa_prop == 'senado') {
      docs <- docs_data %>%
        fuzzyjoin::regex_left_join(senado_env$tipos_documentos, by = c(descricao_tipo_texto = "regex"), ignore_case = T) %>%
        dplyr::mutate(tipo = dplyr::if_else(is.na(tipo), "Outros", tipo),  # default para tipos não agrupados
                      tipo = dplyr::if_else(str_detect(tipo, "P.S"), "Outros", tipo), # Corrige casos de falsos positivos em matérias legislativas.
                      peso = dplyr::if_else(is.na(peso), 0, as.numeric(peso)), # Atribui peso default
                      tipo_acao = dplyr::if_else(is.na(tipo_acao), "Outros", tipo_acao)) %>%
        # Remove casos duplicados usando o peso do regex na ordem de precedência
        dplyr::group_by(id_principal, casa, id_documento, id_autor) %>%
        dplyr::mutate(max_peso = max(peso)) %>%
        dplyr::ungroup() %>%
        dplyr::filter(peso == max_peso) %>%
        dplyr::select(-regex, -peso, -max_peso)

    } else {
      warning('Casa inválida')
    }
  }

  return(docs)

}

#' @title Concatena siglas de unidade federativa de cada autor da proposição
#' @description Retorna unidade federativa dos autores
#' @param autor_df Autores da proposição
#' @return character
get_uf_autores <- function(autor_df) {
  autores_uf <- (paste(unlist(t(autor_df$ultimoStatus.siglaUf)),collapse="+"))
  return(autores_uf)
}

#' @title Concatena siglas de partido de cada autor da proposição
#' @description Retorna partido dos autores
#' @param autor_df Autores da proposição
#' @return character
get_partido_autores <- function(autor_df) {
  autores_partido <- (paste(unlist(t(autor_df$ultimoStatus.siglaPartido)),collapse="+"))
  return(autores_partido)
}


#' @export
get_all_leggo_props_ids <- function(leggo_props_df) {
  pls_ids_camara <- leggo_props_df %>%
    dplyr::mutate(casa = "camara") %>%
    dplyr::select(id_principal = id_camara,casa,apelido,tema) %>%
    dplyr::filter(!is.na(id_principal))

  pls_ids_senado <- leggo_props_df %>%
    dplyr::mutate(casa = "senado") %>%
    dplyr::select(id_principal = id_senado,casa,apelido,tema) %>%
    dplyr::filter(!is.na(id_principal))

  pls_ids_all <- dplyr::bind_rows(pls_ids_camara,pls_ids_senado)
  return(pls_ids_all)
}

safe_fetch_proposicao <- purrr::safely(rcongresso::fetch_proposicao,otherwise = tibble::tibble())

#' @title Realiza busca das informações de um documento
#' @description Retorna dados de um documento caso a requisição seja bem-sucedida,
#' caso contrário retorna um Dataframe vazio
#' @param id_documento ID do documento
#' @param casa casa onde o documento foi apresentado
#' @return Dataframe com dados do documento
fetch_documento <- function(id_documento, casa) {
  fetch_prop_output <- safe_fetch_proposicao(id_documento, casa)
  if (!is.null(fetch_prop_output$error)) {
    print(fetch_prop_output$error)
  }
  return(fetch_prop_output$result)
}


safe_fetch_autores <- purrr::safely(rcongresso::fetch_autores,otherwise = tibble::tibble())

#' @title Realiza busca dos autores de um documento
#' @description Retorna autores de um documento caso a requisição seja bem-sucedida,
#' caso contrário retorna um Dataframe vazio
#' @param id_documento ID do documento
#' @param casa casa onde o documento foi apresentado
#' @param sigla_tipo Sigla do tipo do documento
#' @return Dataframe contendo dados dos autores do documento
#' @export
fetch_autores_documento <- function(id_documento, casa, sigla_tipo = NA) {
  fetch_prop_output <- safe_fetch_autores(id_documento, casa, sigla_tipo)
  autores_result <- fetch_prop_output$result
  if (!is.null(fetch_prop_output$error)) {
    print(fetch_prop_output$error)
  } else {
    autores_result <- autores_result %>%
      dplyr::mutate(id_documento = id_documento)
  }
  return(autores_result)
}

#' @title Realiza o pareamento dos dados dos autores dos documentos do Senado obtidos via endpoint com parlamentares de ambas as casas
#' @description Retorna os autores pareados com seus respectivos ids (em suas respectivas casas),
#' caso não seja possível parear retorna um Dataframe vazio
#' @param autores_senado dataframe com autores dos documentos
#' @param senadores_df dataframe com dados dos senadores das últimas legislaturas
#' @param deputados_df dataframe com dados dos deputados das últimas legislaturas
#' @return Dataframe contendo dados dos autores com seus respectivos ids em suas respectivas casas
#' @export
match_autores_senado_to_parlamentares <- function(autores_senado, senadores_df, deputados_df) {

  if (!agoradigital::check_dataframe(autores_senado)) return(tibble::tibble())
  if (!agoradigital::check_dataframe(senadores_df)) return(tibble::tibble())
  if (!agoradigital::check_dataframe(deputados_df)) return(tibble::tibble())

  tipos_autores_scrap <- senado_env$tipos_autores_scrap

  autores_senado_tipo <- autores_senado %>%
    fuzzyjoin::regex_left_join(tipos_autores_scrap, by=c("nome_autor" = "regex")) %>%
    dplyr::select(-regex) %>%
    dplyr::mutate(tipo_autor = dplyr::if_else(is.na(tipo_autor),"nao_parlamentar",tipo_autor)) %>%
    dplyr::mutate(nome_autor_clean = tolower(stringr::str_trim(stringr::str_replace(nome_autor,
                                                                                    "(\\()(.*?)(\\))|(^Deputad(o|a) Federal )|(^Deputad(o|a) )|(^Senador(a)* )|(^Líder do ((.*?)(\\s)))|(^Presidente do Senado Federal: Senador )", ""))))

  autores_senado_tipo_senadores <- match_autores_senado_scrap_to_senadores(autores_senado_tipo %>% dplyr::filter(tipo_autor == 'senador'),
                                                                           senadores_df)
  autores_senado_tipo_deputados <- match_autores_senado_scrap_to_deputados(autores_senado_tipo %>% dplyr::filter(tipo_autor == 'deputado'),
                                                                           deputados_df)

  senado_autores_scrap_com_id <- dplyr::bind_rows(autores_senado_tipo_senadores,autores_senado_tipo_deputados) %>%
    dplyr::bind_rows((autores_senado_tipo %>% dplyr::filter(tipo_autor == "nao_parlamentar") %>% dplyr::mutate(id_autor = NA))) %>%
    dplyr::select(-nome_autor_clean)

  return(senado_autores_scrap_com_id)
}

#' @title Realiza o pareamento dos dados dos autores dos documentos do Senado obtidos via scrapping da página com senadores
#' @description Retorna os autores pareados com seus respectivos ids no Senado,
#' caso não seja possível parear retorna um Dataframe vazio
#' @param autores_senado_scrap_senadores dataframe com autores dos documentos que são senadores
#' @param senadores_df dataframe com dados dos senadores das últimas legislaturas
#' @return Dataframe contendo dados dos autores com seus respectivos ids no Senado
match_autores_senado_scrap_to_senadores <- function(autores_senado_scrap_senadores, senadores_df) {
  if (!agoradigital::check_dataframe(autores_senado_scrap_senadores)) return(tibble::tibble())
  if (!agoradigital::check_dataframe(senadores_df)) return(tibble::tibble())

  senadores_ids <- senadores %>% dplyr::select(nome_eleitoral, id_autor = id_parlamentar) %>% dplyr::mutate(nome_eleitoral = tolower(nome_eleitoral))

  autores_senado_tipo_senadores <- autores_senado_scrap_senadores %>%
    dplyr::left_join(senadores_ids, by = c("nome_autor_clean"="nome_eleitoral"))
  return(autores_senado_tipo_senadores)
}

#' @title Realiza o pareamento dos dados dos autores dos documentos do Senado obtidos via scrapping da página com deputados
#' @description Retorna os autores pareados com seus respectivos ids na Câmara,
#' caso não seja possível parear retorna um Dataframe vazio
#' @param autores_senado_scrap_senadores dataframe com autores dos documentos que são deputados
#' @param senadores_df dataframe com dados dos deputados das últimas legislaturas
#' @return Dataframe contendo dados dos autores com seus respectivos ids na Câmara
match_autores_senado_scrap_to_deputados <- function(autores_senado_scrap_deputados, deputados_df) {
  if (!agoradigital::check_dataframe(autores_senado_scrap_deputados)) return(tibble::tibble())
  if (!agoradigital::check_dataframe(deputados_df)) return(tibble::tibble())

  deputados_ids <- deputados %>% dplyr::select(ultimo_status_nome_eleitoral, id_autor = id) %>% dplyr::mutate(ultimo_status_nome_eleitoral = tolower(ultimo_status_nome_eleitoral))

  autores_senado_tipo_deputados <- autores_senado_scrap_deputados %>%
    dplyr::left_join(deputados_ids, by = c("nome_autor_clean"="ultimo_status_nome_eleitoral"))

  return(autores_senado_tipo_deputados)
}

#' @title Classifica o tipo de documento com base na coluna com a descrição do tipo de documento.
#' @description A partir da coluna descricao_tipo_documento ou tipo_documento_ext, classifica o tipo do documento em grupos principais
#' como emendas, requerimentos, projetos de lei, etc.
#' @param docs Dataframe com informação do tipo de documento a serem classificados.
#' (é necessário ter as colunas casa, descricao_tipo_documento, id_principal, id_documento, id_autor).
#' Para o Senado a coluna utilizada para classificar o tipo de documento é tipo_documento_ext.
#' @return Dataframe contendo uma coluna a mais com o tipo_documento
#' @examples classifica_tipo_documento_autorias(autorias)
#' @export
classifica_tipo_documento_autorias <- function(docs) {
  docs_camara <- docs %>%
    filter(casa == "camara") %>%
    fuzzyjoin::regex_left_join(camara_env$tipos_documentos, by = c(descricao_tipo_documento = "regex"), ignore_case = T) %>%
    dplyr::mutate(tipo = dplyr::if_else(is.na(tipo), "Outros", tipo),
                  peso = dplyr::if_else(is.na(peso), 0, as.numeric(peso)),
                  tipo_acao = dplyr::if_else(is.na(tipo_acao), "Outros", tipo_acao)) %>%
    dplyr::group_by(id_principal, casa, id_documento, id_autor) %>%
    mutate(max_peso = max(peso)) %>%
    ungroup() %>%
    filter(peso == max_peso) %>%
    dplyr::select(-regex, -peso, -max_peso)

  docs_senado <- docs %>%
    filter(casa == "senado") %>%
    fuzzyjoin::regex_left_join(senado_env$tipos_documentos, by = c(tipo_documento_ext = "regex"), ignore_case = T) %>%
    dplyr::mutate(tipo = dplyr::if_else(is.na(tipo), "Outros", tipo), # default para tipos não agrupados
                  tipo = dplyr::if_else(str_detect(tipo, "P.S"), "Outros", tipo), # Corrige casos de falsos positivos em matérias legislativas.
                  peso = dplyr::if_else(is.na(peso), 0, as.numeric(peso)), # Atribui peso default
                  tipo_acao = dplyr::if_else(is.na(tipo_acao), "Outros", tipo_acao)) %>%
    # Remove casos duplicados usando o peso do regex na ordem de precedência
    dplyr::group_by(id_principal, casa, id_documento, id_autor) %>%
    mutate(max_peso = max(peso)) %>%
    ungroup() %>%
    filter(peso == max_peso) %>%
    dplyr::select(-regex, -peso, -max_peso)

  docs_alt <- docs_camara %>%
    dplyr::bind_rows(docs_senado) %>%
    rename(tipo_documento = tipo)

  return(docs_alt)
}

#' @title Processa dataframe de proposições usando lógica de otimização
#' @description A partir do csv de proposições, adiciona relator para as proposições que tiveram modificações e 
#' une com as que não modificaram.
#' @param proposicoes Dataframe de proposições que mudaram e que não mudaram
#' @param parlamentares Dataframe com os parlamentares
#' @return Dataframe com relator_id e relator_id_parlametria mapeados.
process_proposicoes <- function(proposicoes, parlamentares) {
  if (nrow(proposicoes) > 0) {
    
    if (!"relator_id_parlametria" %in% names(proposicoes)) {
      proposicoes <- proposicoes %>%
        dplyr::mutate(relator_id_parlametria = NA_integer_)
    }
    
    if ("relator_data" %in% names(proposicoes)) {
      proposicoes_sem_relator_mapeado <- proposicoes %>%
        dplyr::filter(!is.na(relator_data)) %>%
        agoradigital::mapeia_nome_relator_para_id(parlamentares)
      
      proposicoes <- proposicoes %>%
        dplyr::filter(is.na(relator_data)) %>%
        dplyr::select(
          id_ext,
          sigla_tipo,
          numero,
          ementa,
          data_apresentacao,
          casa,
          casa_origem,
          regime_tramitacao,
          forma_apreciacao,
          relator_id,
          relator_id_parlametria,
          id_leggo,
          uri_prop_principal,
          sigla
        ) %>%
        dplyr::bind_rows(proposicoes_sem_relator_mapeado) %>%
        dplyr::distinct()
      
    } else {
      proposicoes <- proposicoes %>%
        dplyr::select(
          id_ext,
          sigla_tipo,
          numero,
          ementa,
          data_apresentacao,
          casa,
          casa_origem,
          regime_tramitacao,
          forma_apreciacao,
          relator_id,
          relator_id_parlametria,
          id_leggo,
          uri_prop_principal,
          sigla
        )
    }
  }
  
  return(proposicoes)
}
