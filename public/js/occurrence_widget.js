/*global jQuery, window, document, self, encodeURIComponent, Handlebars, OccurrenceWidget */

var OccurrenceWidget = (function($, window) {

  "use strict";

  var _private = {
    template: "",
    network: [],

    init: function(template, network) {
      this.template = Handlebars.compile(template.html());
      this.network = network;
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
            url: "/user.json?limit=5&q=" + $(agent).text(),
            dataType: "json"
          }).done(function(data) {
            var searched_ids = $.map(data, function(i) { return i.wikidata || i.orcid }),
                icon = $(agent).find("i").removeClass("fa-spinner").removeClass("fa-pulse");
            if (self.findOne(searched_ids, eval(type + "_ids"))) {
              icon.addClass("fa-check").addClass("text-success");
            } else {
              let intersection = $.map(self.network, function(id) { return id.identifier; }).filter(x => searched_ids.includes(x));
              if (intersection.length > 0) {
                icon.remove();
                $(agent).addClass("border").addClass("p-2").find("span").addClass("font-weight-bold").after(self.matchedPersonHTML(intersection[0]));
                self.activateRadios($(agent));
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
          determiner_data = $("[data-user-id]", "#identified").map(function() { return { user_id: $(this).data('user-id'), user_occurrence_id: $(this).data('user-occurrence-id') }; }).get();

      if (determiner_data.map(function(a) { return a.user_id; }).includes(action_input.data("user-id"))) {
        action_input.end().find("input.action-radio[data-action='identified']").prop('checked', true).parent().addClass("active");
        var user_occurrence_id = $.grep(determiner_data, function(a) { return a.user_id === user_id; })[0].user_occurrence_id;
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
          location.reload();
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
        var url = (found.identifier[0] === "Q") ? "https://www.wikidata.org/wiki/" + found.identifier : "https://orcid.org/" + found.identifier;
        if (found.identifier[0] === "Q") {
          img = "<img src=\"/images/wikidata_24x24.png\" class=\"pr-1\" />";
        } else {
          img = "<i class=\"fab fa-orcid pr-1\"></i>";
        }
        output = "<table class=\"mb-2\">";
        output += "<tbody>";
        output += "<tr>";
        output += "<td class=\"selector\">" + this.template({ user_id: found.user_id }) + "</td>";
        output += "<td><span class=\"d-block pl-2\">" + found.fullname_reverse + "<br>" + img + "<a href=\"" + url + "\" target=\"_blank\">" + url + "</a></span></td>";
        output += "</tr>";
        output += "</tbody>";
        output += "</table>";
      }
      return output;
    }
  };

  return {
    init: function(template, network) {
      _private.init(template, network);
    }
  };

}(jQuery, window));
