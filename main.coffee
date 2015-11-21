require "shelljs/global"
require "sugar"
path      = require "path"
fs        = require "fs"
request   = require "superagent"
crypto    = require "crypto"
async     = require "async"
jsonfile  = require "jsonfile"
injecter  = require "./injecter"

MD5_BANLIST = ["index.html", "checksums.json"]

checksum = (str) -> crypto.createHash("md5").update(str, "utf8").digest("hex")

class FileRef
  constructor: (root_path, rel_path) ->
    @abs_path = path.join root_path, rel_path
    @root_path = root_path
    @rel_path = rel_path
  is_dir: -> fs.lstatSync(@abs_path).isDirectory()
  basename: -> path.basename @abs_path
  extname: -> path.extname @abs_path
  is_banned: -> MD5_BANLIST.indexOf(this.basename()) > -1
  get_md5: ->
    if @md5 then return @md5
    data = fs.readFileSync @abs_path
    return checksum(data)
  get_md5_filename: ->
    return this.get_md5() + this.extname()
  upload: (policy, sign, cb) ->
    console.log "上传#{@rel_path}中"
    request
    .post "http://v0.api.upyun.com/avicidev"
    .field "policy", policy
    .field "signature", sign
    .attach "file", @abs_path
    .end cb

get_files_to_process = (project_root) ->
  ls "-R", project_root
  .map (it) -> new FileRef(project_root, it)
  .filter (it) -> !it.is_dir()
  .filter (it) -> !it.is_banned()

retrieve_ls_json = (cb) ->
  request.get("http://avici.io/api/ls").end (err, res) ->
    cb err, res

get_tokens = (upload_token, cb) ->
  request.get("http://avici.io/api/check_upload_token/#{upload_token}").end (err, res) ->
    cb err, res.body

get_artifact_id = (upload_token, cb) ->
  request.get("http://avici.io/api/check_artifact_id/#{upload_token}").end (err, res) ->
    cb err, res.body

module.exports = (token, root) ->
  retrieve_ls_json (err, res) ->
    get_tokens token, (err, token_data) ->
      get_artifact_id token, (err, artifact_id) ->
        data = res.body
        files = get_files_to_process root
        files_to_upload = files.filter (it) ->
          filename_forcheck = it.get_md5_filename()
          return data.indexOf(filename_forcheck) == -1
        # now let us create the files
        checksum_data = {}
        files.each (f) ->
          checksum_data[f.rel_path] = f.get_md5_filename()
        # create the directory
        mkdir path.join(root, ".avici")
        # serialize the checksums.json into it
        jsonfile.writeFileSync path.join(root, ".avici/checksums.json"), checksum_data
        # then let us deal with the index.html
        original_html = cat path.join(root, "index.html")
        to = injecter(original_html, JSON.stringify(checksum_data), artifact_id)
        fs.writeFileSync path.join(root, ".avici/index.html"), to, "utf8"
        rr = token_data.res
        rd = token_data.data

        datafiles = [".avici/index.html",".avici/checksums.json"].map (it) ->
          new FileRef(root, it)
        async.each files_to_upload, ((it, cb) -> it.upload(rr.policy, rr.sign, cb)), (err) ->
          if err then console.log(err)
          console.log "资源上传成功：Upload Resources Finished"
        async.each datafiles, ((it, cb) -> it.upload(rd.policy, rd.sign, cb)), (err) ->
          if err then console.log(err)
          console.log "数据上传成功：Upload Data Finished"
