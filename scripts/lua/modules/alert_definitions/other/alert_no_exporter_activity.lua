--
-- (C) 2019-24 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_no_exporter_activity = classes.class(alert)

-- ##############################################

alert_no_exporter_activity.meta = {  
   alert_key = other_alert_keys.alert_no_exporter_activity,
   i18n_title = "checks.no_exporter_activity_title",
   icon = "fas fa-fw fa-arrow-circle-up",
   entities = {
      alert_entities.interface
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function alert_no_exporter_activity:init(exporter)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
      exporter_no_activity = exporter
   }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_no_exporter_activity.format(ifid, alert, alert_type_params)
  return(i18n("checks.no_activity_on_exporter_description", { exporter = alert_type_params.exporter_no_activity }))
end

-- #######################################################

return alert_no_exporter_activity
