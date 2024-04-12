--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local dscp_consts = require "dscp_consts"

local historical_flow_details_formatter = {}

-- ###############################################

local function format_historical_main_issue(flow)
    local alert_consts = require "alert_consts"
    local alert_label = i18n("flow_details.normal")
    local alert_id = tonumber(flow["STATUS"] or 0)

    -- No status setted
    if (alert_id ~= 0) then
        alert_label = alert_consts.alertTypeLabel(alert_id, true)
    end

    local alert_href = "<a href=\"" .. ntop.getHttpPrefix() ..
                           "/lua/alert_stats.lua?status=historical&page=flow&alert_id=" .. alert_id .. ";eq\">" ..
                           alert_label .. "</a>"

    return {
        name = i18n("alerts_dashboard.alert"),
        values = {alert_href}
    }
end

-- ###############################################

local function format_historical_flow_label(flow)
    local historical_flow_utils = require "historical_flow_utils"

    return {
        name = i18n("flow_details.flow_peers_client_server"),
        values = {historical_flow_utils.getHistoricalFlowLabel(flow, true)}
    }
end

-- ###############################################

local function format_historical_protocol_label(flow)
    local historical_flow_utils = require "historical_flow_utils"

    return {
        name = i18n("protocol") .. " / " .. i18n("application"),
        values = {historical_flow_utils.getHistoricalProtocolLabel(flow, true)}
    }
end

-- ###############################################

local function format_historical_last_first_seen(flow, info)
    return {
        name = i18n("db_explorer.date_time"),
        values = {
            [1] = info.first_seen.time,
            [2] = info.last_seen
        }
    }
end

-- ###############################################

local function format_historical_total_traffic(flow)
    return {
        name = i18n("db_explorer.traffic_info"),
        values = {formatPackets(flow['PACKETS']) .. ' / ' .. bytesToSize(flow['TOTAL_BYTES'])}
    }
end

-- ###############################################

local function format_historical_client_server_bytes(flow)
    return {
        name = "",
        values = {
            [1] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": " ..
                bytesToSize(flow['SRC2DST_BYTES']),
            [2] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server") .. ": " ..
                bytesToSize(flow['DST2SRC_BYTES'])
        }
    }
end

-- ###############################################

local function format_historical_bytes_progress_bar(flow, info)
    local cli2srv = round(((flow["SRC2DST_BYTES"] or 0) * 100) / flow["TOTAL_BYTES"], 0)

    return {
        name = "",
        values = {'<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. cli2srv .. '%;">' ..
            (info.cli_ip.label or '') .. '</div>' .. '<div class="progress-bar bg-success" style="width: ' ..
            (100 - cli2srv) .. '%;">' .. (info.srv_ip.label or '') .. '</div></div>'}
    }
end

-- ###############################################

local function format_historical_tos(flow)
    return {
        name = i18n("db_explorer.tos"),
        values = {
            [1] = dscp_consts.dscp_descr(flow['SRC2DST_DSCP']),
            [2] = dscp_consts.dscp_descr(flow['DST2SRC_DSCP'])
        }
    }
end

-- ###############################################

local function format_historical_tcp_flags(flow, info)
    return {
        name = i18n("tcp_flags"),
        values = {
            [1] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\"></i> " .. i18n("server") .. ": " ..
                info.src2dst_tcp_flags.label,
            [2] = i18n("client") .. " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server") .. ": " ..
                info.dst2src_tcp_flags.label
        }
    }
end

-- ###############################################

local function format_historical_host_pool(flow, info)
    return {
        name = i18n("details.host_pool"),
        values = {
            [1] = i18n("client") .. " " .. i18n("pools.pool") .. ": " .. info.cli_host_pool_id.label,
            [2] = i18n("server") .. " " .. i18n("pools.pool") .. ": " .. info.srv_host_pool_id.label
        }
    }
end

-- ###############################################

local function format_historical_issue_description(flow_details, flow)
    local alert_store_utils = require "alert_store_utils"
    local alert_entities = require "alert_entities"
    local alert_consts = require "alert_consts"
    local format_utils = require "format_utils"
    local alert_store_instances = alert_store_utils.all_instances_factory()
    local alert_utils = require "alert_utils"
    local alert_json = json.decode(flow["ALERT_JSON"] or '') or {}
    local details, alert

    local alert_store_instance = alert_store_instances[alert_entities["flow"].alert_store_name]

    if alert_store_instance then
        local alerts, _ = alert_store_instance:select_request(nil, "*")
        if #alerts >= 1 then
            alert = alerts[1]
            details = alert_utils.formatFlowAlertMessage(interface.getId(), alert, alert_json, false, true)
        else
            tprint(debug.traceback())
            tprint(alerts)
        end
    end

    local alert_consts = require "alert_consts"
    local alert_label = i18n("flow_details.normal")
    local alert_id = tonumber(flow["STATUS"] or 0)
    local severity_id = map_score_to_severity(ntop.getFlowAlertScore(tonumber(alert_id)))
    local severity = alert_consts.alertSeverityById(severity_id)

    -- No status setted
    if (alert_id ~= 0) then
        alert_label = alert_consts.alertTypeLabel(alert_id, true)
        alert_label = alert_label .. " [" .. details .. "]"
    end

    flow_details[#flow_details + 1] = {
        name = i18n("issues_score"),
        values = {alert_label,
                  '<span style="color:' .. severity.color .. '">' ..
            format_utils.formatValue(ntop.getFlowAlertScore(tonumber(alert_id))) .. '</span>'}
    }
    local alert_utils = require "alert_utils"
    local alert_json = json.decode(flow["ALERT_JSON"] or '') or {}
    local _, other_issues = alert_utils.format_other_alerts(flow['ALERTS_MAP'], flow['STATUS'], alert_json, false, nil,
        true)
    if table.len(other_issues) > 0 then
        for _, issues in pairs(other_issues or {}) do
            local severity_id = map_score_to_severity(tonumber(issues.score))
            local severity = alert_consts.alertSeverityById(severity_id)
            flow_details[#flow_details + 1] = {
                name = '', -- Empty label
                values = {issues.msg, '<span style="color:' .. severity.color .. '">' .. issues.score .. '</span>'}
            }
        end
    end
    flow_details[#flow_details + 1] = {
        name = '', -- Empty label
        values = {'<b>' .. i18n('total_flow_score') .. '</b>',
                  '<span style="color:' .. severity.color .. '">' .. format_utils.formatValue(tonumber(flow["SCORE"])) ..
            '</span>'}
    }

    return flow_details
end

-- ###############################################

local function format_tcp_connection_states(info)

    local conn_states = {}
    conn_states[#conn_states + 1] = string.format("%s: %s (%s)", i18n("flow_fields_description.major_connection_state"),
        i18n(string.format("flow_fields_description.major_connection_states.%s", info.major_connection_state.value)),
        i18n(string.format("flow_fields_description.minor_connection_states_info.%u", info.minor_connection_state.value)))
    conn_states[#conn_states + 1] = string.format("%s: %s (%s)", i18n("flow_fields_description.minor_connection_state"),
        i18n(string.format("flow_fields_description.minor_connection_states.%s", info.minor_connection_state.value)),
        i18n(string.format("flow_fields_description.minor_connection_states_info.%u", info.minor_connection_state.value)))
    return conn_states
end

-- ###############################################

local function format_historical_community_id(flow)
    return {
        name = i18n("db_explorer.community_id"),
        values = {flow["COMMUNITY_ID"]}
    }
end

-- ###############################################

local function format_historical_info(flow)
    local historical_flow_utils = require "historical_flow_utils"
    local info_field = historical_flow_utils.get_historical_url(flow["INFO"], "info", flow["INFO"], true, flow["INFO"],
        true)

    return {
        name = i18n("db_explorer.info"),
        values = {info_field}
    }
end

-- ###############################################

local function format_historical_probe(flow, info)
    local historical_flow_utils = require "historical_flow_utils"
    local format_utils = require "format_utils"

    local alias = getFlowDevAlias(info["probe_ip"]["value"], true)
    local name

    if alias == info["probe_ip"]["value"] then
        name = format_name_value(info["probe_ip"]["value"], info["probe_ip"]["label"], true)
    else
        name = alias
    end

    local info_field = {
        device_ip = historical_flow_utils.get_historical_url(name, "probe_ip", info["probe_ip"]["value"], true,
            info["probe_ip"]["title"])
    }

    if (flow["INPUT_SNMP"]) and (tonumber(flow["INPUT_SNMP"]) ~= 0) then
        info_field["input_interface"] = historical_flow_utils.get_historical_url(
            format_utils.formatSNMPInterface(flow["PROBE_IP"], flow["INPUT_SNMP"]), "input_snmp",
            info["input_snmp"]["value"], true, info["input_snmp"]["title"])
    end

    if (flow["OUTPUT_SNMP"]) and (tonumber(flow["OUTPUT_SNMP"]) ~= 0) then
        info_field["output_interface"] = historical_flow_utils.get_historical_url(
            format_utils.formatSNMPInterface(flow["PROBE_IP"], flow["OUTPUT_SNMP"]), "output_snmp",
            info["output_snmp"]["value"], true, info["output_snmp"]["title"])
    end

    return {
        name = i18n("details.flow_snmp_localization"),
        values = {info_field}
    }
end

-- ###############################################

local function format_historical_latency(flow, value, cli_or_srv)
    return {
        name = i18n("db_explorer." .. cli_or_srv .. "_latency"),
        values = {(tonumber(flow[value]) / 1000) .. " msec"}
    }
end

-- ###############################################

local function format_historical_obs_point(flow)
    return {
        name = i18n("db_explorer.observation_point"),
        values = {getObsPointAlias(flow["OBSERVATION_POINT_ID"], true, true)}
    }
end

-- ###############################################

local function format_historical_proto_info(flow_details, proto_info)
    local info = format_proto_info(flow_details, proto_info)
    return info
end
-- ###############################################

local function format_historical_flow_traffic_stats(rowspan, cli2srv_retr, srv2cli_retr, cli2srv_ooo, srv2cli_ooo,
    cli2srv_lost, srv2cli_lost)
    local values = {"<tr><th width=30% rowspan=" .. rowspan .. ">" .. i18n("flow_details.tcp_packet_analysis") ..
        "</th><th></th><th>" .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-right\" ></i> " .. i18n("server") ..
        " / " .. i18n("client") .. " <i class=\"fas fa-long-arrow-alt-left\"></i> " .. i18n("server") .. "</th></tr>\n"}

    if ((cli2srv_retr and (tonumber(cli2srv_retr) > 0)) or (srv2cli_retr and (tonumber(srv2cli_retr) > 0))) then
        values[#values + 1] = "<tr><th>" .. i18n("details.retransmissions") .. "</th><td><span id=c2sretr>" ..
                                  formatPackets(cli2srv_retr) .. "</span> / <span id=s2cretr>" ..
                                  formatPackets(srv2cli_retr) .. "</span></td></tr>\n"
    end

    if ((cli2srv_ooo and (tonumber(cli2srv_ooo) > 0)) or (srv2cli_ooo and (tonumber(srv2cli_ooo) > 0))) then
        values[#values + 1] = "<tr><th>" .. i18n("details.out_of_order") .. "</th><td><span id=c2sOOO>" ..
                                  formatPackets(cli2srv_ooo) .. "</span> / <span id=s2cOOO>" ..
                                  formatPackets(srv2cli_ooo) .. "</span></td></tr>\n"
    end

    if ((cli2srv_lost and (tonumber(cli2srv_lost) > 0)) or (srv2cli_lost and (tonumber(srv2cli_lost) > 0))) then
        values[#values + 1] = "<tr><th>" .. i18n("details.lost") .. "</th><td><span id=c2slost>" ..
                                  formatPackets(cli2srv_lost) .. "</span> / <span id=s2clost>" ..
                                  formatPackets(srv2cli_lost) .. "</span></td></tr>\n"
    end

    return {
        values = values
    }
end

local function format_historical_flow_rtt(client_nw_latency, server_nw_latency)
    local rtt = client_nw_latency + server_nw_latency
    local cli2srv = round(client_nw_latency, 3)
    local srv2cli = round(server_nw_latency, 3)
    local values =
        '<div class="progress"><div class="progress-bar bg-warning" style="width: ' .. (cli2srv * 100 / rtt) .. '%;">' ..
            cli2srv .. ' ms (client)</div>' .. '<div class="progress-bar bg-success" style="width: ' ..
            (srv2cli * 100 / rtt) .. '%;">' .. srv2cli .. ' ms (server)</div></div>'
    return {
        name = i18n("flow_details.rtt_breakdown"),
        values = {values}
    }

end

-- ###############################################

-- This function format the historical flow details page
function historical_flow_details_formatter.formatHistoricalFlowDetails(flow)
    local historical_flow_utils = require "historical_flow_utils"
    local flow_details = {}

    if flow then
        local info = historical_flow_utils.format_clickhouse_record(flow)
        flow_details[#flow_details + 1] = format_historical_flow_label(flow)
        flow_details[#flow_details + 1] = format_historical_protocol_label(flow)
        flow_details[#flow_details + 1] = format_historical_last_first_seen(flow, info)
        flow_details[#flow_details + 1] = format_historical_total_traffic(flow)
        flow_details[#flow_details + 1] = format_historical_client_server_bytes(flow)
        flow_details[#flow_details + 1] = format_historical_bytes_progress_bar(flow, info)

        if ((tonumber(flow["SERVER_NW_LATENCY_US"]) > 0) or (tonumber(flow["CLIENT_NW_LATENCY_US"]) > 0)) then
            flow_details[#flow_details + 1] = format_historical_flow_rtt(tonumber(flow["SERVER_NW_LATENCY_US"]),
                tonumber(flow["CLIENT_NW_LATENCY_US"]))
        end

        if (info['dst2src_dscp']) and (info['src2dst_dscp']) then
            flow_details[#flow_details + 1] = format_historical_tos(flow)
        end

        if (info["l4proto"]) and (info["l4proto"]["label"] == 'TCP') then
            flow_details[#flow_details + 1] = format_historical_tcp_flags(flow, info)

            if (info["major_connection_state"] ~= 0 and info["minor_connection_state"] ~= 0) then
                local conn_states = format_tcp_connection_states(info)

                for _, state in pairs(conn_states or {}) do
                    flow_details[#flow_details + 1] = {
                        name = '', -- Empty label
                        values = {state}
                    }
                end

            end

        end

        if (info["cli_host_pool_id"]) and (info["cli_host_pool_id"]["value"] ~= '0') and
            (info["srv_host_pool_id"]["value"] ~= '0') then
            flow_details[#flow_details + 1] = format_historical_host_pool(flow, info)
        end

        if (info["score"]) and (info["score"]["value"] ~= 0) then
            flow_details = format_historical_issue_description(flow_details, flow)
        end

        if (info['COMMUNITY_ID']) and (not isEmptyString(info['COMMUNITY_ID'])) then
            flow_details[#flow_details + 1] = format_historical_community_id(flow)
        end

        if (info['info']) and (not isEmptyString(info['info']["title"])) then
            flow_details[#flow_details + 1] = format_historical_info(flow)
        end

        if (flow["PROBE_IP"] and not isEmptyString(flow['PROBE_IP']) and (flow['PROBE_IP'] ~= '0.0.0.0')) then
            flow_details[#flow_details + 1] = format_historical_probe(flow, info)
        end

        if tonumber(flow["CLIENT_NW_LATENCY_US"]) ~= 0 then
            flow_details[#flow_details + 1] = format_historical_latency(flow, "CLIENT_NW_LATENCY_US", "cli")
        end

        if tonumber(flow["SERVER_NW_LATENCY_US"]) ~= 0 then
            flow_details[#flow_details + 1] = format_historical_latency(flow, "SERVER_NW_LATENCY_US", "srv")
        end
        local alert_json = json.decode(flow["ALERT_JSON"] or '') or {}

        if (alert_json["traffic_stats"] and table.len(alert_json["traffic_stats"]) > 0) then
            local rowspan = 1;

            if (alert_json["traffic_stats"]["cli2srv.retransmissions"] ~= 0 or
                alert_json["traffic_stats"]["srv2cli.retransmissions"] ~= 0) then
                rowspan = rowspan + 1
            end

            if (alert_json["traffic_stats"]["cli2srv.out_of_order"] ~= 0 or
                alert_json["traffic_stats"]["srv2cli.out_of_order"] ~= 0) then
                rowspan = rowspan + 1
            end

            if (alert_json["traffic_stats"]["cli2srv.lost"] ~= 0 or alert_json["traffic_stats"]["srv2cli.lost"] ~= 0) then
                rowspan = rowspan + 1
            end

            flow_details[#flow_details + 1] = format_historical_flow_traffic_stats(rowspan,
                alert_json["traffic_stats"]["cli2srv.retransmissions"],
                alert_json["traffic_stats"]["srv2cli.retransmissions"],
                alert_json["traffic_stats"]["cli2srv.out_of_order"],
                alert_json["traffic_stats"]["srv2cli.out_of_order"], alert_json["traffic_stats"]["cli2srv.lost"],
                alert_json["traffic_stats"]["srv2cli.lost"])
        end

        if tonumber(flow["OBSERVATION_POINT_ID"]) ~= 0 then
            flow_details[#flow_details + 1] = format_historical_obs_point(flow)
        end

        if table.len(alert_json["proto"]) > 0 then
            flow_details = format_historical_proto_info(flow_details, alert_json["proto"])

            if (type(flow_details[#flow_details]['values']) == 'table') and
                (table.len(flow_details[#flow_details]['values']) == 0) then
                table.remove(flow_details, #flow_details)
            end
        end
    end

    return flow_details
end

return historical_flow_details_formatter
