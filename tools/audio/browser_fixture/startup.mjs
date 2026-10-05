const modules = ['fixture', 'livekit_pair_fixture', 'microphone_join_fixture',
  'audio_input_fixture', 'voice_parity/fixture']

export async function warmAudioModules(server) {
  await Promise.all(modules.map(async name => {
    const result = await server.transformRequest(`/tests/audio/${name}.ts`)
    if (!result) throw new Error('Audio fixture module did not transform: '+name)
  }))
  // Finish the static import graph before browsers consume optimized dependency URLs.
  await server.waitForRequestsIdle()
}
