readlineSync  = require "readline-sync"
chalk         = require "chalk"
sh            = require "shelljs"
main          = require "./main"

module.exports = ->
  console.log chalk.yellow("Autoci 上传工具")
  console.log "当前文件夹：#{sh.pwd()}"
  console.log "请输入游戏的上传秘钥："
  game_token = readlineSync.question "> "
  main game_token, "C:/Users/picc/Documents/Games/RTP"
