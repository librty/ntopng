<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("acknowledge_alerts") }}
    </template>
    <template v-slot:body>
      <div class="form-group row">
        <div class="col-sm-6">
          <label class="col-form-label"><b>{{ _i18n("date_from") }}</b></label>
        </div>
        <div class="col-sm-6">
          <input class="form-control" type="text" :value="begin_time" disabled="">
        </div>
      </div>
      <div class="form-group row mb-2">
        <div class="col-sm-6">
          <label class="col-form-label"><b>{{ _i18n("date_from") }}</b></label>
        </div>
        <div class="col-sm-6 mt-1">
          <input class="form-control" type="text" :value="end_time" disabled="">
        </div>
      </div>

      <AlertInfo :no_close_button="true" ref="alert_info"></AlertInfo>
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="acknowledge_alerts" class="btn btn-primary">{{ _i18n("acknowledge") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { ntopng_utility, ntopng_url_manager, ntopng_events_manager, ntopng_events } from "../services/context/ntopng_globals_services";
import filtersManager from "../utilities/filters-manager.js";

const props = defineProps({
  page: String,
  context: Object,
});
const emit = defineEmits(["acknowledge_alerts"]);

const id = "modal-acknowledge-alerts";
const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const alert_info = ref(null);
const begin_time = ref("");
const end_time = ref("");
const filters = ref([]);

onMounted(() => {
});

const show = (status) => {
  begin_time.value = ntopng_utility.from_utc_to_server_date_format(status.epoch_begin * 1000);
  end_time.value = ntopng_utility.from_utc_to_server_date_format(status.epoch_end * 1000);
  let message_body = _i18n("show_alerts.confirm_acknowledge_alerts");
  alert_info.value.show(message_body, "alert-danger");
  modal_id.value.show();
};

async function acknowledge_alerts() {
  let url = `${http_prefix}/lua/rest/v2/acknowledge/${props.page}/alerts.lua`;
  /* The SNMP page is the only exception where the url totally changes */
  if (props.page == 'snmp_device') {
    url = `${http_prefix}/lua/pro/rest/v2/acknowledge/snmp/device/alerts.lua`
  }
  const url_params_obj = ntopng_url_manager.get_url_object();
  const params = {
    csrf: props.context.csrf,
    ...url_params_obj,
  };
  await ntopng_utility.http_post_request(url, params);
  emit("acknowledge_alerts");
  close();
}

const close = () => {
  modal_id.value.close();
};

defineExpose({ show, close });

</script>
