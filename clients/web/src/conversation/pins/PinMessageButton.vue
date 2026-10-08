<script setup lang="ts">
import { onBeforeUnmount,ref } from 'vue'
import { pinMessage } from './client'
import { notifyLocalPinChange } from '../reactions/hints'
const props=defineProps<{channelId:string;messageId:string}>()
const busy=ref(false),error=ref(''),notice=ref('');let alive=true
onBeforeUnmount(()=>{alive=false})
async function pin():Promise<void>{
  if(busy.value)return;busy.value=true;error.value='';notice.value=''
  const channel=props.channelId,message=props.messageId
  try{await pinMessage(channel,message,true);if(alive&&channel===props.channelId&&message===props.messageId){notice.value='Сообщение закреплено.';notifyLocalPinChange(channel,message)}}
  catch(reason){if(alive)error.value=reason instanceof Error?reason.message:'Закрепление недоступно.'}
  finally{if(alive)busy.value=false}
}
</script>
<template><span><button type="button" :disabled="busy" @click="pin">Закрепить сообщение</button><small v-if="notice" role="status">{{notice}}</small><small v-if="error" role="alert">{{error}}</small></span></template>
<style scoped>button{min-height:28px;border:1px solid var(--gc-border);border-radius:14px;background:transparent;color:inherit;padding:3px 8px}small{display:block}</style>
