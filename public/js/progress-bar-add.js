/*global jQuery, window, document, self, encodeURIComponent */
var ProgressBarAdd = (function($, window) {

   "use strict";
 
   var _private = {
 
     identifier: "",
 
     init: function(identifier) {
       this.identifier = typeof identifier !== 'undefined' ? identifier : "";
       this.ajax_setup();
       return this.add_user();
     },

     ajax_setup: function() {
       $.ajaxSetup({
         headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
       });
     },

     format_user_link: function(data) {
      var link = "";
      if (data.identifier[0] == "Q") {
         link += "<img src=\"/images/wikidata_18x12.svg\" alt=\"Wikidata iD\" class=\"mr-1\">";
      } else {
         link += "<i class=\"fab fa-orcid\"></i>";
      }
      link += "<a href=\"/help-others/" + data.identifier + "\">" + data.fullname + "</a>";
      return link;
     },

     format_unsuccessful: function() {
      var html = "";
      if (typeof Handlebars !== 'undefined' && $("#failed-result").length > 0) {
         html = Handlebars.compile($("#failed-result").html());
      }
      return html; 
     },

     add_user: function() {
       var self = this, progress_bar = $(".progress div[data-identifier='" + this.identifier + "']");
       return $.ajax({
           method: "POST",
           url: "/help-others/add-user.json",
           contentType: "application/json",
           dataType: "json",
           data: JSON.stringify({
            identifier: this.identifier
           })
         }).done(function(data) {
            if (data.identifier) {
              progress_bar.width('100%');
              progress_bar.removeClass("bg-info").addClass("bg-success");
              progress_bar.parent().parent().next().html(self.format_user_link(data));
            } else {
              progress_bar.width('100%');
              progress_bar.removeClass("bg-info").addClass("bg-danger");
              progress_bar.parent().parent().next().html(self.format_unsuccessful()).find("i").tooltip();
            }
         }).fail(function(data) {
            progress_bar.width('100%');
            progress_bar.removeClass("bg-info").addClass("bg-danger");
            progress_bar.parent().parent().next().html(self.format_unsuccessful()).find("i").tooltip();
         });
     },
 
   };
 
   return {
     init: function(identifier) {
       return _private.init(identifier);
     }
   };
 
 }(jQuery, window));
 