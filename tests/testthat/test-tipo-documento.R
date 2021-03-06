context("Tipo de Documento")

# Setup
setup <- function(){
  tipos_documentos <- c("Emenda","Prop. Original / Apensada","Parecer","Requerimento","Voto em Separado","Outros")
  tipos_acao <- c("Proposição", "Recurso", "Outros")
  regex_documento_emenda_acao <<- tipos_acao[1]
  regex_documento_proposicao_acao <<-tipos_acao[1]
  regex_documento_requerimento_acao <<-tipos_acao[1]
  regex_documento_voto_em_separado_acao <<-tipos_acao[2]
  regex_documento_outros_acao <<-  tipos_acao[3]
  regex_documento_parecer_acao <<- tipos_acao[3]

  regex_documento_emenda <<- tipos_documentos[1]
  regex_documento_proposicao <<- tipos_documentos[2]
  regex_documento_parecer <<- tipos_documentos[3]
  regex_documento_requerimento <<- tipos_documentos[4]
  regex_documento_voto_em_separado <<- tipos_documentos[5]
  regex_documento_outros <<- tipos_documentos[6]

  docs_emendas <<- tibble::tibble(descricao_tipo_documento = c("Emenda",
                                                   "Emenda adotada pela comissão",
                                                   "Emenda adotada pela comissao",
                                                   "Emenda ao substitutivo",
                                                   "Emenda ao plenário",
                                                   "Emenda ao plenario",
                                                   "Emenda de redação",
                                                   "Emenda de redacao",
                                                   "Emenda na comissão",
                                                   "Emenda na comissao",
                                                   "Emenda/substitutivo do senado",
                                                   "Subemenda de relator",
                                                   "Subemenda substitutiva de plenário",
                                                   "Subemenda substitutiva de plenario"),
                                  id_principal = rep(1, 14),
                                  id_autor = rep(31, 14),
                                  id_documento = 1:14,
                                  casa = rep('camara',14))

  docs_emendas_gt <<- dplyr::mutate(docs_emendas, tipo = rep(regex_documento_emenda,14), tipo_acao = rep(regex_documento_emenda_acao,14))

  docs_proposicoes <<- tibble::tibble(descricao_tipo_documento = c("Medida provisoria",
                                                          "Medida provisória",
                                                          "Projeto de lei",
                                                          "Projeto de lei complementar",
                                                          "Projeto de lei de conversão",
                                                          "Projeto de lei de conversao",
                                                          "Proposta de Emenda a constituicao",
                                                          "Proposta de Emenda à constituição"),
                                      id_principal = 1:8,
                                      id_autor = rep(1, 8),
                                      id_documento = 9:16,
                                      casa = rep('camara',8))

  docs_proposicoes_gt <<- dplyr::mutate(docs_proposicoes, tipo = rep(regex_documento_proposicao,8), tipo_acao= rep(regex_documento_proposicao_acao,8))

  docs_pareceres <<- tibble::tibble(descricao_tipo_documento = c("Parecer às Emendas apresentadas ao substitutivo do relator",
                                                     "Parecer às Emendas de plenário",
                                                     "Parecer às Emendas ou ao substitutivo do senado",
                                                     "Parecer de comissão",
                                                     "Parecer de comissão para redação final",
                                                     "Parecer do relator",
                                                     "Parecer proferido em plenário",
                                                     "Parecer reformulado",
                                                     "Parecer reformulado de plenário",
                                                     "Parecer vencedor",
                                                     "Complementação de voto",
                                                     "Complementacao de voto",
                                                     "Redação final",
                                                     "Redacao Final",
                                                     "Substitutivo",
                                                     "Substitutivo adotado pela Comissão",
                                                     "Substitutivo adotado pela comissao"),
                                    id_principal = 1:17,
                                    id_autor = rep(1, 17),
                                    id_documento = 18:34,
                                    casa = rep('camara',17))

  docs_pareceres_gt <<- dplyr::mutate(docs_pareceres, tipo = rep(regex_documento_parecer,17), tipo_acao = rep(regex_documento_parecer_acao,17))

  docs_requerimentos <<- tibble::tibble(descricao_tipo_documento = c("Requerimento",
                                                         "Requerimento de apensação",
                                                         "Requerimento de audiência pública",
                                                         "Requerimento de constituição de comissão especial de pec",
                                                         "Requerimento de constituição de comissão especial de projeto",
                                                         "Requerimento de convocação de ministro de estado na comissão",
                                                         "Requerimento de desapensação",
                                                         "Requerimento de desarquivamento de proposições",
                                                         "Requerimento de envio de proposições pendentes de parecer à comissão seguinte ou ao plenário",
                                                         "Requerimento de inclusão de matéria extra-pauta na ordem do dia das comissões",
                                                         "Requerimento de inclusão na ordem do dia",
                                                         "Requerimento de informação",
                                                         "Requerimento de participação ou realização de eventos fora da câmara",
                                                         "Requerimento de prorrogação de prazo de comissão temporária",
                                                         "Requerimento de reconstituição de proposição",
                                                         "Requerimento de redistribuição",
                                                         "Requerimento de retirada de assinatura em proposição de iniciativa coletiva",
                                                         "Requerimento de retirada de assinatura em proposição que não seja de iniciativa coletiva",
                                                         "Requerimento de retirada de proposição",
                                                         "Requerimento de retirada de proposição de iniciativa coletiva",
                                                         "Requerimento de retirada de proposição de iniciativa individual",
                                                         "Requerimento de transformação de sessão plenaria em comissão geral",
                                                         "Requerimento de urgência (art. 154 do ricd)",
                                                         "Requerimento de urgência (art. 155 do ricd)"),
                                        id_principal = rep(1, 24),
                                        id_autor = 1:24,
                                        id_documento = 1:24,
                                        casa = rep('camara',24))

  docs_requerimentos_gt <<- dplyr::mutate(docs_requerimentos, tipo = rep(regex_documento_requerimento,24), tipo_acao= rep(regex_documento_requerimento_acao,24))

  docs_voto_em_separado <<- tibble::tibble(descricao_tipo_documento = c("Voto em Separado"),
                                           id_principal = 1,
                                           id_autor = 1,
                                           id_documento = 1,
                                           casa = c('camara'))

  docs_voto_em_separado_gt <<- dplyr::mutate(docs_voto_em_separado, tipo = c(regex_documento_voto_em_separado), tipo_acao = c(regex_documento_voto_em_separado_acao))

  docs_outros <<- tibble::tibble(descricao_tipo_documento = c("Ata",
                                                  "Autógrafo",
                                                  "Mensagem",
                                                  "Reclamação"),
                                 id_principal = rep(1, 4),
                                 id_autor = rep(1, 4),
                                 id_documento = 1:4,
                                 casa = rep('camara',4))

  docs_outros_gt <<- dplyr::mutate(docs_outros, tipo = rep(regex_documento_outros,4), tipo_acao = rep(regex_documento_outros_acao,4))

  return(TRUE)
}

check_api <- function(){
  tryCatch(setup(), error = function(e){return(FALSE)})
}

test <- function(){
  test_that("Regex do tipo do documento funciona para as emendas", {
    expect_equal(add_tipo_evento_documento(docs_emendas), docs_emendas_gt)
  })

  test_that("Regex do tipo do documento funciona para as proposicoes", {
    expect_equal(add_tipo_evento_documento(docs_proposicoes),docs_proposicoes_gt)
  })

  test_that("Regex do tipo do documento funciona para os pareceres", {
    expect_equal(add_tipo_evento_documento(docs_pareceres),docs_pareceres_gt)
  })

  test_that("Regex do tipo do documento funciona para os requerimentos", {
    expect_equal(add_tipo_evento_documento(docs_requerimentos),docs_requerimentos_gt)
  })

  test_that("Regex do tipo do documento funciona para o voto em separado", {
    expect_equal(add_tipo_evento_documento(docs_voto_em_separado),docs_voto_em_separado_gt)
  })

  test_that("Regex do tipo do documento funciona para Outros", {
    expect_equal(add_tipo_evento_documento(docs_outros),docs_outros_gt)
  })

}

if(check_api()){
  test()
} else testthat::skip('Erro no setup!')
