var cheerio = require("cheerio");
var sh = require("shelljs");
var path = require("path").posix;
var swig = require("swig");
require("sugar");

function inject(html_file, json_data, artifact_id){
  var AVICI_BASE_PATH = "//avici.io/html/files/" + artifact_id + "/";
  var contents = html_file;

  var $ = cheerio.load(contents);

  $("script").each(function(i, ele){
    $(ele).attr("src", function(i, old){
      return AVICI_BASE_PATH + old;
    });
  });

  $("link").each(function(i, ele){
    $(ele).attr("href", function(i, old){
      return AVICI_BASE_PATH + old;
    });
  });


  var appended = [
    swig.renderFile("./templates/json_init.html", {json_data: function(){return json_data;}}),
    '<script type="text/javascript" src="' + "//avici.io/html/static/" + artifact_id +"/inject.js" +'"></script>'
  ].join("");
  $("body").children().last().before(appended);
  console.log($.html());
  return $.html();
}

module.exports = inject;
