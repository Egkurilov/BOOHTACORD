<script setup lang="ts">
import { guildProfile } from './state'
const name = guildProfile.name
</script>
<template><span class="guild-profile-name" :title="name">{{ name }}</span></template>
<style scoped>.guild-profile-name { display: block; min-width: 0; max-width: 100%; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }</style>
