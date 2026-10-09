export const ux2026RequiredViewports = [
  { width: 320, height: 640 },
  { width: 390, height: 844 },
  { width: 768, height: 1024 },
  { width: 1024, height: 768 },
  { width: 1440, height: 900 },
  { width: 1920, height: 1080 },
] as const

export const ux2026ReferenceViewports = [
  { width: 1440, height: 900 },
  { width: 393, height: 852 },
] as const

export const ux2026ShellViewports = [
  ux2026RequiredViewports[0],
  { width: 375, height: 812 },
  ux2026RequiredViewports[1],
  ux2026ReferenceViewports[1],
  { width: 430, height: 932 },
  { width: 600, height: 900 },
  ux2026RequiredViewports[2],
  { width: 840, height: 390 },
  ux2026RequiredViewports[3],
  { width: 1280, height: 800 },
  ux2026RequiredViewports[4],
  ux2026RequiredViewports[5],
] as const
