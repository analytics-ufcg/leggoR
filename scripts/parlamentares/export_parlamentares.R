#!/usr/bin/env Rscript
library(magrittr)
library(tidyverse)

source(here::here("scripts/parlamentares/process_parlamentares.R"))
source(here::here("scripts/entidades/process_entidades.R"))

if (!require(optparse)) {
  install.packages("optparse")
  suppressWarnings(suppressMessages(library(optparse)))
}

args = commandArgs(trailingOnly = TRUE)

message("Use --help para mais informações\n")
option_list = list(
  make_option(
    c("-o", "--out"),
    type = "character",
    default = here::here("data/"),
    help = "Caminho do diretório que terão os arquivos de saída [default= %default]",
    metavar = "character"
  ),
  make_option(
    c("-c", "--casa"),
    type = "character",
    default = NA,
    help = "Casa que se deseja atualizar os parlamentares. O default é baixar câmara e senado",
    metavar = "character"
  ),
  make_option(
    c("-f", "--flag"),
    type = "character",
    default = 1,
    help = "Flag para baixar somente os dados das últimas legislaturas (55 e 56). [default= %default]",
    metavar = "character"
  )
)

opt_parser = OptionParser(option_list = option_list)
opt = parse_args(opt_parser)

export_path <- opt$out
casa <- opt$casa
only_lasts_legislatures_flag <- opt$flag

if (!str_detect(export_path, "\\/$")) {
  export_path <- paste0(export_path, "/")
}

print("Criando diretório destino...")

if (!is.na(casa)) {
  dir.create(paste0(export_path, casa), showWarnings = FALSE)
} else {
  dir.create(paste0(export_path, 'camara'), showWarnings = FALSE)
  dir.create(paste0(export_path, 'senado'), showWarnings = FALSE)
}

if (only_lasts_legislatures_flag == 1) {
  legislaturas <- c(55, 56)
} else {
  legislaturas <- seq(51, 56)
}

update_deputados <- function(legislaturas) {
  deputados <- .process_deputados(legislaturas)
  
  readr::write_csv(deputados,
                   paste0(export_path, "camara/parlamentares.csv"))
}

update_senadores <- function(legislaturas, casa) {
  senadores <- .process_senadores(legislaturas)
  
  readr::write_csv(senadores,
                   paste0(export_path, "senado/parlamentares.csv"))
}

if (is.na(casa)) {
  parlamentares_filepath <- paste0(export_path, "parlamentares.csv")
  parlamentares <- .process_parlamentares(legislaturas)
  readr::write_csv(parlamentares,
                   parlamentares_filepath)
  
  entidades <- .process_entidades(parlamentares_filepath)
  write_csv(entidades, paste0(export_path, "entidades.csv"))
  
} else {
  if (casa == "camara") {
    update_deputados()
    
  } else if (casa == "senado") {
    update_senadores()
    
  } else {
    print("Parâmetro inválido!")
  }
  
}
