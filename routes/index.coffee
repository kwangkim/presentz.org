fs = require "fs"
path = require "path"
_ = require "underscore"
_s = require "underscore.string"
http = require "http"
url = require "url"
dateutil = require "dateutil"

class NotFound extends Error
  constructor: (msg) ->
    @name = 'NotFound'
    Error.call this, msg
    Error.captureStackTrace this, arguments.callee
    
render_catalog = (catalog, presentations, req, res) ->
  presentations = _.sortBy presentations, (pres) -> 
    pres.id
  presentations = presentations.reverse()
  res.render "catalog",
    title: "#{catalog.name} is on Presentz",
    catalog: catalog
    presentations: presentations
    
fill_presentation_data_from_file= (file, file_name, files_length, catalog, presentations, req, res) ->
  fs.readFile file, "utf-8", (err, data) ->
    data = JSON.parse data
    pres =
      id: "#{req.params.catalog_name}/#{file_name.substr(0, file_name.indexOf("."))}"
      data: data
      thumb: data.chapters[0].media.video.thumb

    if data.speaker
      pres.title1 = data.speaker
      pres.title1 = "#{dateutil.format(dateutil.parse(data.time, "YYYYMMDD"), "Y/m")} - #{pres.title1}" if data.time
      pres.title2 = data.title
    else
      pres.title1 = data.title
    pres.title = pres.title1
    pres.title += " - #{pres.title2}" if pres.title2

    presentations.push pres
    render_catalog catalog, presentations, req, res if files_length == presentations.length

collect_presentations = (err, files, catalog_path, req, res, catalog) ->
  files = (file for file in files when not _s.startsWith(file, "catalog") and _s.endsWith(file, ".json"))
  presentations = []
  for file in files
    fill_presentation_data_from_file "#{catalog_path}/#{file}", file, files.length, catalog, presentations, req, res
  return
  
read_catalog = (catalog_path, req, next, callback) ->
  fs.readFile "#{catalog_path}/catalog.json", "utf-8", (err, data) ->
    return next new NotFound("catalog in #{catalog_path}") if err
    catalog = JSON.parse data
    catalog.id = req.params.catalog_name
    callback(catalog)
    
find_file = (path, filename, callback) ->
  fs.readdir path, (err, files) ->
    throw next new NotFound(path) if err
    filtered_files = _.filter files, (file) ->
      file.indexOf(filename) isnt -1
    if filtered_files.length is 1
      callback filtered_files[0].substring(0, filtered_files[0].indexOf("."))
    else
      callback

exports.static = (view_name) ->
  return (req, res) ->
    res.render view_name,
      title: "Presentz"
  
exports.show_catalog= (req, res, next) ->
  catalog_path = "#{__dirname}/../#{req.params.catalog_name}"
  path.exists catalog_path, (exists) ->
    return next new NotFound(catalog_path) if not exists
    read_catalog catalog_path, req, next, (catalog) ->
      fs.readdir catalog_path, (err, files) -> 
        collect_presentations err, files, catalog_path, req, res, catalog

exports.show_presentation= (req, res, next) ->
  catalog_path = "#{__dirname}/../#{req.params.catalog_name}"
  read_catalog catalog_path, req, next, (catalog) ->
    fs.readFile "#{__dirname}/..#{req.path}.json", "utf-8", (err, data) ->
      return next new NotFound("#{__dirname}/..#{req.path}.json") if err
      pres = JSON.parse data
      res.render "presentation",
        title: pres.title_long || pres.title
        catalog: catalog
        url: "#{req.url_original || req.url}.json"
        thumb: pres.chapters[0].media.video.thumb
      
exports.raw_presentation= (req, res, next) ->
  fs.readFile "#{__dirname}/..#{req.path}", "utf-8", (err, data) ->
    return next new NotFound("#{__dirname}/..#{req.path}.json") if err
    data = "#{req.query.jsoncallback}(#{data});" if req.query.jsoncallback
    res.send data
    
exports.redirect_to_presentation_from_html= (req, res, next) ->
  catalog_path = "#{__dirname}/../#{req.params.catalog_name}"
  find_file catalog_path, req.params.presentation, (file) ->
    res.redirect "http://#{options.host}/#{file}", 302
  
exports.redirect_to_presentation_from_p_html= (req, res, next) ->
  console.log req.params
  res.send req.params
