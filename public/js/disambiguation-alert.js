/*global jQuery, window, document, self, encodeURIComponent */
var DisambiguateSearch = (function($, window) {

  "use strict";

  var _private = {

    name: "",
    identifier: "",

    init: function(name, identifier) {
      this.name = name;
      this.identifier = typeof identifier !== 'undefined' ? identifier : "";
      this.search();
    },

    search: function() {
      var self = this;
      $.ajax({
        method: "GET",
        url: "/user.json?limit=10&q=" + this.name
      }).done(function(data) {
        var item = data.find(element => (element.orcid == self.identifier || element.wikidata == self.identifier));
        if (item != null) {
          var score = item.score;
          data.splice(data.indexOf(item), 1);
          if (data.some(e => (score - e.score) < 5)) {
            //TODO
          }
        }
      });
    }
  };

  return {
    init: function(name, identifier) {
      return _private.init(name, identifier);
    }
  };

}(jQuery, window));
