/*global jQuery, window, document, self, encodeURIComponent, Handlebars, OccurrenceWidget */

var OccurrenceWidget = (function($, window) {

  "use strict";

  var _private = {
    template: "",
    network: [],
    ignored: [],

    init: function(template, network, ignored) {
      this.template = Handlebars.compile(template.html());
      this.network = network;
      this.ignored = ignored;
      this.ajax_setup();
      this.search_agents();
    },

    ajax_setup: function() {
      $.ajaxSetup({
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') }
      });
    },

    search_agents: function() {
      var self = this,
          recorders_ids = $("p.orcid[data-recorders]").map(function() { return $(this).data('recorders'); }).get(),
          determiners_ids = $("p.orcid[data-determiners]").map(function() { return $(this).data('determiners'); }).get();

      $.each(['recorders', 'determiners'], function() {
        var type = this;

        $('.agent_' + type).each(function() {
          var agent = this;
          $.ajax({
            method: "GET",
            url: "/user.json?limit=3&q=" + $(agent).text(),
            dataType: "json"
          }).done(function(data) {
            var searched_ids = $.map(data, function(i) { return i.wikidata || i.orcid }),
                icon = $(agent).find("i").removeClass("fa-spinner").removeClass("fa-pulse"),
                ignored = $.map(self.ignored, function(i) { return i.identifier; });

            var searched_filtered = searched_ids.filter(item => !ignored.includes(item));

            if (self.findOne(searched_filtered, eval(type + "_ids"))) {
              icon.addClass("fa-check").addClass("text-success");
            } else {
              let intersection = $.map(self.network, function(id) { return id.identifier; }).filter(x => searched_filtered.includes(x));
              if (intersection.length) {
                icon.remove();
                $(agent).addClass("border").addClass("my-2").find("span").wrap("<div class=\"p-2\"></div>").parent().after(self.matchedPersonHTML(intersection[0]));
                self.activateRadios($(agent));
                self.activateNotThem($(agent));
              } else {
                icon.addClass("fa-question").addClass("text-warning");
              }
            }
          });
        });
      });
    },

    activateRadios: function(ele) {
      var action_input = $(ele).find("input.action-radio"),
          occurrence_id = parseInt(action_input.attr("data-occurrence-id"), 10),
          user_id = parseInt(action_input.attr("data-user-id"), 10),
          url = "/help-others/user-occurrence/" + occurrence_id + ".json",
          method = "POST",
          determiner_data = $("[data-user-id]", "#identification").map(function() { if ($(this).data('user-occurrence-id')) { return { user_id: $(this).data('user-id'), user_occurrence_id: $(this).data('user-occurrence-id') }; } }).get(),
          recorder_data = $("[data-user-id]", "#event").map(function() { if ($(this).data('user-occurrence-id')) { return { user_id: $(this).data('user-id'), user_occurrence_id: $(this).data('user-occurrence-id') }; } }).get();

      if (determiner_data.map(function(a) { return a.user_id; }).includes(action_input.data("user-id"))) {
        action_input.end().find("input.action-radio[data-action='identified']").prop('checked', true).parent().addClass("active");
        var user_occurrence_id = $.grep(determiner_data, function(a) { return a.user_id === user_id; })[0].user_occurrence_id;
        url = "/help-others/user-occurrence/" + user_occurrence_id + ".json";
        method = "PUT";
      } else if (recorder_data.map(function(a) { return a.user_id; }).includes(action_input.data("user-id"))) {
        action_input.end().find("input.action-radio[data-action='recorded']").prop('checked', true).parent().addClass("active");
        var user_occurrence_id = $.grep(recorder_data, function(a) { return a.user_id === user_id; })[0].user_occurrence_id;
        url = "/help-others/user-occurrence/" + user_occurrence_id + ".json";
        method = "PUT";
      }

      action_input.on("change", function() {
        var row = $(this).parents("tr"),
            action = $(this).attr("data-action");

        $.ajax({
          method: method,
          url: url,
          dataType: "json",
          data: JSON.stringify({
            user_id: user_id,
            action: action,
            visible: true
          }),
          beforeSend: function(xhr) {
            $("label", row).addClass("disabled");
            $("button", row).addClass("disabled");
          }
        }).done(function(data) {
          if ($('#carousel').length) {
            $('#carousel').carousel('next');
          } else {
            location.reload();
          }
        });

      });
    },

    activateNotThem: function(ele) {
      var action_input = $(ele).find("button.action-not-them"),
          user_id = parseInt(action_input.attr("data-user-id"), 10),
          occurrence_id = parseInt(action_input.attr("data-occurrence-id"), 10),
          url = "/help-others/user-occurrence/" + occurrence_id + ".json"

      action_input.on('click', function() {
        $.ajax({
          method: "POST",
          url: url,
          data: JSON.stringify({
            user_id: user_id,
            visible: 0
          }),
          beforeSend: function(xhr) {
            action_input.addClass("disabled");
          }
        }).done(function() {
          if ($('#carousel').length) {
            $('#carousel').carousel('next');
          } else {
            location.reload();
          }
        });
      });
    },

    findOne: function(haystack, arr) {
      return arr.some(function (v) {
        return haystack.indexOf(v) >= 0;
      });
    },

    matchedPersonHTML: function(id) {
      var output = "", img = "";
      let found = this.network.find(x => x.identifier === id);
      if (found) {
        var url = (found.identifier[0] === "Q") ? "http://www.wikidata.org/entity/" + found.identifier : "https://orcid.org/" + found.identifier;
        if (found.identifier[0] === "Q") {
          img = "<img src=\"/images/wikidata_24x15.svg\" class=\"pr-1\" />";
        } else {
          img = "<i class=\"fab fa-orcid pr-1\"></i>";
        }
        output = "<div class=\"row m-0 py-2 border-top bg-light\">";
        var lifespan = (found.identifier[0] === "Q") ? "<small class=\"muted\">" + found.lifespan + "</small><br>" : "";
        output += "<div class=\"col m-0\"><span class=\"d-block font-weight-bold\">" + found.fullname_reverse + "</span>" + lifespan + img + "<a href=\"" + url + "\">" + url + "</a></div>";
        output += "<div class=\"col-md-auto m-0 selector text-left\">" + this.template({ user_id: found.user_id }) + "</div>";
        output += "</div>";
      }
      return output;
    }
  };

  return {
    init: function(template, network, ignored) {
      _private.init(template, network, ignored);
    }
  };

}(jQuery, window));
