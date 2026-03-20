<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import * as THREE from 'three'

// 状态
const activeTab = ref('scene')
const isStreaming = ref(false)
const isRecording = ref(false)
const recordingTime = ref(0)
const cameras = ref<MediaDeviceInfo[]>([])
const selectedCameraId = ref('')
let mediaStream: MediaStream | null = null

// 场景/素材/镜头
const scenes = ref([
  { id: 1, name: '默认场景', icon: '🎬', type: 'scene' },
  { id: 2, name: '绿幕抠像', icon: '🟢', type: 'chroma' },
  { id: 3, name: '虚拟演播室', icon: '🏢', type: 'scene' },
  { id: 4, name: '电竞风格', icon: '🎮', type: 'scene' },
  { id: 5, name: '商务风格', icon: '💼', type: 'scene' },
  { id: 6, name: '清新风格', icon: '🌸', type: 'scene' },
])
const materials = ref([
  { id: 1, name: '背景1.jpg', icon: '🖼️', type: 'image' },
  { id: 2, name: '背景2.jpg', icon: '🖼️', type: 'image' },
  { id: 3, name: 'LOGO.png', icon: '🏷️', type: 'image' },
  { id: 4, name: '开场动画', icon: '🎬', type: 'video' },
  { id: 5, name: '转场动画', icon: '🔄', type: 'video' },
  { id: 6, name: '背景音乐', icon: '🎵', type: 'audio' },
])
const lenses = ref([
  { id: 'l1', name: '主机位', icon: '📷', active: true },
  { id: 'l2', name: '侧全景', icon: '🔭', active: false },
  { id: 'l3', name: '特写', icon: '🔎', active: false },
  { id: 'l4', name: '远景', icon: '🌐', active: false },
  { id: 'l5', name: '中景', icon: '👤', active: false },
  { id: 'l6', name: '全景', icon: '🌄', active: false },
])
const activeLens = ref('l1')

// 3D 虚拟背景
const enable3DScene = ref(true)
const current3DScene = ref('cyberpunk')

// Three.js 变量
let threeScene: THREE.Scene | null = null
let threeCamera: THREE.PerspectiveCamera | null = null
let threeRenderer: THREE.WebGLRenderer | null = null
let threeCanvasEl: HTMLCanvasElement | null = null
let threeAnimationId: number | null = null

// 3D 场景列表
const threeDScenes = [
  { id: 'cyberpunk', name: '赛博朋克', icon: '🌃' },
  { id: 'liveshow', name: 'Live舞台', icon: '🎤' },
  { id: 'studio', name: '虚拟演播室', icon: '🏢' },
  { id: 'nature', name: '自然风光', icon: '🌲' },
  { id: 'space', name: '太空站', icon: '🚀' },
]

// 初始化 3D 场景
function init3DScene() {
  threeCanvasEl = document.getElementById('three-canvas') as HTMLCanvasElement
  if (!threeCanvasEl) return
  
  threeScene = new THREE.Scene()
  threeCamera = new THREE.PerspectiveCamera(75, 1920/1080, 0.1, 1000)
  threeCamera.position.z = 5
  
  threeRenderer = new THREE.WebGLRenderer({ canvas: threeCanvasEl, alpha: true, antialias: true })
  threeRenderer.setSize(1920, 1080)
  threeRenderer.setClearColor(0x000000, 0)
  
  // 添加环境光
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
  threeScene.add(ambientLight)
  
  // 添加点光源
  const pointLight = new THREE.PointLight(0x00d9ff, 1, 100)
  pointLight.position.set(0, 5, 5)
  threeScene.add(pointLight)
  
  create3DElements(current3DScene.value)
  animate3D()
}

function create3DElements(sceneType: string) {
  if (!threeScene) return
  
  // 清除现有元素
  while(threeScene.children.length > 0) { 
    threeScene.remove(threeScene.children[0]) 
  }
  
  // 重新添加灯光
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.6)
  threeScene.add(ambientLight)
  const pointLight = new THREE.PointLight(0x00d9ff, 1, 100)
  pointLight.position.set(0, 5, 5)
  threeScene.add(pointLight)
  
  if (sceneType === 'cyberpunk') {
    // 霓虹网格地面
    const gridHelper = new THREE.GridHelper(20, 20, 0xff00ff, 0x00ffff)
    gridHelper.position.y = -2
    threeScene.add(gridHelper)
    
    // 漂浮光球
    for (let i = 0; i < 8; i++) {
      const geometry = new THREE.SphereGeometry(0.2 + Math.random() * 0.3, 16, 16)
      const material = new THREE.MeshBasicMaterial({ 
        color: Math.random() > 0.5 ? 0xff00ff : 0x00ffff 
      })
      const sphere = new THREE.Mesh(geometry, material)
      sphere.position.set(
        (Math.random() - 0.5) * 10,
        Math.random() * 4 - 1,
        (Math.random() - 0.5) * 6 - 2
      )
      sphere.userData = { speed: 0.01 + Math.random() * 0.02, originalY: sphere.position.y }
      threeScene!.add(sphere)
    }
  } else if (sceneType === 'liveshow') {
    // === 赛博 Live Show 舞台 ===
    
    // 舞台地板 - 黑色反光
    const stageGeo = new THREE.PlaneGeometry(16, 10)
    const stageMat = new THREE.MeshStandardMaterial({ 
      color: 0x111111, 
      roughness: 0.2, 
      metalness: 0.8 
    })
    const stage = new THREE.Mesh(stageGeo, stageMat)
    stage.rotation.x = -Math.PI / 2
    stage.position.y = -2
    threeScene.add(stage)
    
    // 舞台边缘霓虹灯
    const edgeGeo = new THREE.BoxGeometry(16, 0.1, 0.3)
    const edgeMat = new THREE.MeshBasicMaterial({ color: 0xff00ff })
    const frontEdge = new THREE.Mesh(edgeGeo, edgeMat)
    frontEdge.position.set(0, -1.95, 4)
    threeScene.add(frontEdge)
    const backEdge = new THREE.Mesh(edgeGeo, edgeMat)
    backEdge.position.set(0, -1.95, -4)
    threeScene.add(backEdge)
    
    // LED 屏幕背景墙
    const screenGeo = new THREE.PlaneGeometry(14, 7)
    const screenMat = new THREE.MeshBasicMaterial({ 
      color: 0x001133,
      emissive: 0x003366,
      emissiveIntensity: 0.5
    })
    const screen = new THREE.Mesh(screenGeo, screenMat)
    screen.position.set(0, 1, -4.5)
    threeScene.add(screen)
    
    // 屏幕边框
    const frameGeo = new THREE.BoxGeometry(14.4, 7.4, 0.2)
    const frameMat = new THREE.MeshStandardMaterial({ color: 0x222222, metalness: 0.9 })
    const frame = new THREE.Mesh(frameGeo, frameMat)
    frame.position.set(0, 1, -4.6)
    threeScene.add(frame)
    
    // 舞台灯光 - 4个霓虹柱
    const pillarColors = [0xff00ff, 0x00ffff, 0xff00ff, 0x00ffff]
    for (let i = 0; i < 4; i++) {
      const pillarGeo = new THREE.CylinderGeometry(0.15, 0.15, 6, 8)
      const pillarMat = new THREE.MeshBasicMaterial({ 
        color: pillarColors[i],
        transparent: true,
        opacity: 0.7
      })
      const pillar = new THREE.Mesh(pillarGeo, pillarMat)
      pillar.position.set(-5 + i * 3.33, 1, -3)
      threeScene.add(pillar)
      
      // 柱子顶部灯光
      const topLight = new THREE.PointLight(pillarColors[i], 2, 8)
      topLight.position.set(-5 + i * 3.33, 4, -3)
      threeScene.add(topLight)
    }
    
    // 舞台灯光 - 正面两个
    const frontLight1 = new THREE.SpotLight(0xff00ff, 3)
    frontLight1.position.set(-3, 6, 4)
    frontLight1.angle = Math.PI / 8
    frontLight1.penumbra = 0.5
    threeScene.add(frontLight1)
    
    const frontLight2 = new THREE.SpotLight(0x00ffff, 3)
    frontLight2.position.set(3, 6, 4)
    frontLight2.angle = Math.PI / 8
    frontLight2.penumbra = 0.5
    threeScene.add(frontLight2)
    
    // 舞台正面 Logo 灯牌
    const logoGeo = new THREE.PlaneGeometry(4, 1)
    const logoMat = new THREE.MeshBasicMaterial({ 
      color: 0xff00ff,
      emissive: 0xff00ff,
      emissiveIntensity: 1
    })
    const logo = new THREE.Mesh(logoGeo, logoMat)
    logo.position.set(0, 4, -4.4)
    threeScene.add(logo)
    
    // 地面反射效果（用透明平面模拟）
    const reflectionGeo = new THREE.PlaneGeometry(16, 10)
    const reflectionMat = new THREE.MeshBasicMaterial({
      color: 0xff00ff,
      transparent: true,
      opacity: 0.1
    })
    const reflection = new THREE.Mesh(reflectionGeo, reflectionMat)
    reflection.rotation.x = -Math.PI / 2
    reflection.position.y = -1.99
    threeScene.add(reflection)
    
    // 添加一些漂浮的光粒子效果
    for (let i = 0; i < 20; i++) {
      const particleGeo = new THREE.SphereGeometry(0.03, 8, 8)
      const particleMat = new THREE.MeshBasicMaterial({ 
        color: Math.random() > 0.5 ? 0xff00ff : 0x00ffff 
      })
      const particle = new THREE.Mesh(particleGeo, particleMat)
      particle.position.set(
        (Math.random() - 0.5) * 12,
        Math.random() * 5,
        (Math.random() - 0.5) * 6
      )
      particle.userData = { speed: 0.005 + Math.random() * 0.01, originalY: particle.position.y }
      threeScene.add(particle)
    }
  } else if (sceneType === 'studio') {
    // 演播室 - 墙壁和地面
    const floorGeo = new THREE.PlaneGeometry(20, 20)
    const floorMat = new THREE.MeshStandardMaterial({ color: 0x333344, roughness: 0.8 })
    const floor = new THREE.Mesh(floorGeo, floorMat)
    floor.rotation.x = -Math.PI / 2
    floor.position.y = -2
    threeScene.add(floor)
    
    // 背景墙
    const wallGeo = new THREE.PlaneGeometry(20, 10)
    const wallMat = new THREE.MeshStandardMaterial({ color: 0x222233 })
    const wall = new THREE.Mesh(wallGeo, wallMat)
    wall.position.z = -5
    threeScene.add(wall)
    
    // 灯光
    const spotLight = new THREE.SpotLight(0xffffff, 2)
    spotLight.position.set(0, 8, 2)
    spotLight.angle = Math.PI / 6
    spotLight.penumbra = 0.3
    threeScene.add(spotLight)
  } else if (sceneType === 'space') {
    // 太空 - 星星背景
    for (let i = 0; i < 200; i++) {
      const starGeo = new THREE.SphereGeometry(0.02 + Math.random() * 0.05)
      const starMat = new THREE.MeshBasicMaterial({ color: 0xffffff })
      const star = new THREE.Mesh(starGeo, starMat)
      star.position.set(
        (Math.random() - 0.5) * 30,
        (Math.random() - 0.5) * 20,
        (Math.random() - 0.5) * 20 - 10
      )
      threeScene.add(star)
    }
    
    // 地球
    const earthGeo = new THREE.SphereGeometry(2, 32, 32)
    const earthMat = new THREE.MeshStandardMaterial({ color: 0x2244ff, roughness: 0.8 })
    const earth = new THREE.Mesh(earthGeo, earthMat)
    earth.position.set(5, 0, -8)
    threeScene.add(earth)
  } else if (sceneType === 'nature') {
    // 自然 - 草地和天空
    const groundGeo = new THREE.PlaneGeometry(30, 30)
    const groundMat = new THREE.MeshStandardMaterial({ color: 0x228833, roughness: 1 })
    const ground = new THREE.Mesh(groundGeo, groundMat)
    ground.rotation.x = -Math.PI / 2
    ground.position.y = -2
    threeScene.add(ground)
    
    // 天空渐变球
    const skyGeo = new THREE.SphereGeometry(15, 32, 32)
    const skyMat = new THREE.MeshBasicMaterial({ color: 0x87ceeb, side: THREE.BackSide })
    const sky = new THREE.Mesh(skyGeo, skyMat)
    threeScene.add(sky)
    
    // 树木
    for (let i = 0; i < 5; i++) {
      const trunkGeo = new THREE.CylinderGeometry(0.2, 0.3, 1.5)
      const trunkMat = new THREE.MeshStandardMaterial({ color: 0x8b4513 })
      const trunk = new THREE.Mesh(trunkGeo, trunkMat)
      trunk.position.set(-5 + i * 2.5, -1.25, -5)
      threeScene.add(trunk)
      
      const leavesGeo = new THREE.ConeGeometry(1, 2, 8)
      const leavesMat = new THREE.MeshStandardMaterial({ color: 0x228b22 })
      const leaves = new THREE.Mesh(leavesGeo, leavesMat)
      leaves.position.set(-5 + i * 2.5, 0.5, -5)
      threeScene.add(leaves)
    }
  }
}

function animate3D() {
  if (!threeRenderer || !threeScene || !threeCamera) return
  
  // 动画效果
  threeScene.children.forEach((child: any) => {
    if (child.userData && child.userData.speed) {
      child.position.y = child.userData.originalY + Math.sin(Date.now() * 0.001) * 0.3
    }
  })
  
  threeRenderer.render(threeScene, threeCamera)
  threeAnimationId = requestAnimationFrame(animate3D)
}

function switch3DScene(sceneId: string) {
  current3DScene.value = sceneId
  create3DElements(sceneId)
}

// 设置
const chromaKey = ref({ enabled: false, color: '#00ff00', similarity: 40, smoothness: 10, spillRemoval: 20 })
const color = ref({ brightness: 0, contrast: 0, saturation: 0, temperature: 0 })
const effect = ref({ blur: 0, shadow: 0, highlight: 0, vignette: 0 })
const live = ref({ url: '', key: '', enabled: false })
const record = ref({ format: 'mp4', quality: 'high', fps: 30 })

// refs
const videoRef = ref<HTMLVideoElement | null>(null)
const previewCanvas = ref<HTMLCanvasElement | null>(null)
const outputCanvas = ref<HTMLCanvasElement | null>(null)
let ctx: CanvasRenderingContext2D | null = null
let outCtx: CanvasRenderingContext2D | null = null
let animationFrame: number | null = null
let mediaRecorder: MediaRecorder | null = null
let recordedChunks: Blob[] = []

// 摄像头
async function getCameras() {
  try {
    // 先请求权限
    await navigator.mediaDevices.getUserMedia({ video: true, audio: true })
    const devices = await navigator.mediaDevices.enumerateDevices()
    cameras.value = devices.filter(d => d.kind === 'videoinput')
    console.log('发现摄像头:', cameras.value.length)
    if (cameras.value.length && !selectedCameraId.value) selectedCameraId.value = cameras.value[0].deviceId
  } catch (e: any) {
    console.error('获取摄像头列表失败:', e)
  }
}

async function startCamera() {
  try {
    // 先尝试获取权限
    const constraints: MediaStreamConstraints = {
      video: {
        width: { ideal: 1280 },
        height: { ideal: 720 },
        deviceId: selectedCameraId.value ? { exact: selectedCameraId.value } : undefined
      },
      audio: true
    }
    
    mediaStream = await navigator.mediaDevices.getUserMedia(constraints)
    if (videoRef.value) { 
      videoRef.value.srcObject = mediaStream 
      await videoRef.value.play()
    }
    isStreaming.value = true
    startPreview()
  } catch (e: any) {
    console.error('摄像头错误:', e)
    alert('无法启动摄像头: ' + (e.message || '请检查权限'))
  }
}

function stopCamera() {
  if (mediaStream) { mediaStream.getTracks().forEach(t => t.stop()); mediaStream = null }
  if (animationFrame) { cancelAnimationFrame(animationFrame); animationFrame = null }
  isStreaming.value = false
}

function startPreview() {
  if (!videoRef.value || !previewCanvas.value || !outputCanvas.value) return
  const v = videoRef.value, c = previewCanvas.value, o = outputCanvas.value
  c.width = o.width = 1920; c.height = o.height = 1080
  ctx = c.getContext('2d', { willReadFrequently: true })!
  outCtx = o.getContext('2d')!
  
  // 初始化 3D 场景
  if (enable3DScene.value) {
    setTimeout(init3DScene, 100)
  }

  function draw() {
    if (!isStreaming.value || !ctx || !outCtx) return
    ctx.drawImage(v, 0, 0, c.width, c.height)
    if (chromaKey.value.enabled) applyChromaKey()
    if (color.value.brightness || color.value.contrast) applyColor()
    if (effect.value.vignette > 0) applyVignette()
    
    // 叠加 3D 背景
    if (enable3DScene.value && threeCanvasEl) {
      outCtx.drawImage(threeCanvasEl, 0, 0)
      outCtx.globalAlpha = 0.9
      outCtx.drawImage(c, 0, 0)
      outCtx.globalAlpha = 1
    } else {
      outCtx.drawImage(c, 0, 0)
    }
    animationFrame = requestAnimationFrame(draw)
  }
  draw()
}

function applyChromaKey() {
  if (!ctx) return
  const img = ctx.getImageData(0, 0, 1920, 1080), d = img.data, sim = chromaKey.value.similarity
  const key = hexToRgb(chromaKey.value.color)
  for (let i = 0; i < d.length; i += 4) {
    const dist = Math.sqrt((d[i]-key.r)**2 + (d[i+1]-key.g)**2 + (d[i+2]-key.b)**2)
    if (dist < sim) { d[i+3] = Math.max(0, 255 - dist / sim * 255) }
  }
  ctx.putImageData(img, 0, 0)
}

function applyColor() {
  if (!ctx) return
  const img = ctx.getImageData(0, 0, 1920, 1080), d = img.data
  const { brightness, contrast, saturation } = color.value
  for (let i = 0; i < d.length; i += 4) {
    let r = d[i] + brightness * 2.55, g = d[i+1] + brightness * 2.55, b = d[i+2] + brightness * 2.55
    r = ((r/255 - 0.5) * (contrast + 100) / 100 + 0.5) * 255
    g = ((g/255 - 0.5) * (contrast + 100) / 100 + 0.5) * 255
    b = ((b/255 - 0.5) * (contrast + 100) / 100 + 0.5) * 255
    const gray = 0.299*r + 0.587*g + 0.114*b, sat = 1 + saturation/100
    d[i] = Math.max(0, Math.min(255, gray + (r-gray)*sat))
    d[i+1] = Math.max(0, Math.min(255, gray + (g-gray)*sat))
    d[i+2] = Math.max(0, Math.min(255, gray + (b-gray)*sat))
  }
  ctx.putImageData(img, 0, 0)
}

function applyVignette() {
  if (!ctx) return
  const g = ctx.createRadialGradient(960, 540, 400, 960, 540, 960)
  g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${effect.value.vignette/100})`)
  ctx.fillStyle = g; ctx.fillRect(0, 0, 1920, 1080)
}

function hexToRgb(hex: string) {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex)
  return m ? { r: parseInt(m[1],16), g: parseInt(m[2],16), b: parseInt(m[3],16) } : {r:0,g:255,b:0}
}

function switchLens(id: string) { activeLens.value = id; lenses.value.forEach(l => l.active = l.id === id) }

// 录制
function startRecording() {
  if (!outputCanvas.value) return
  const stream = outputCanvas.value.captureStream(record.value.fps)
  if (mediaStream) mediaStream.getAudioTracks().forEach(t => stream.addTrack(t))
  mediaRecorder = new MediaRecorder(stream, { mimeType: record.value.format==='mp4'?'video/mp4':'video/webm' })
  mediaRecorder.ondataavailable = e => e.data.size && recordedChunks.push(e.data)
  mediaRecorder.onstop = () => {
    const url = URL.createObjectURL(new Blob(recordedChunks))
    const a = document.createElement('a'); a.href = url; a.download = `XRShowMaster_${Date.now()}.${record.value.format}`; a.click()
  }
  mediaRecorder.start()
  isRecording.value = true
  recordingTime.value = setInterval(() => recordingTime.value++, 1000) as unknown as number
}

function stopRecording() { mediaRecorder?.stop(); isRecording.value = false; clearInterval(recordingTime.value) }
function formatTime(s: number) { return `${Math.floor(s/3600).toString().padStart(2,'0')}:${Math.floor(s%3600/60).toString().padStart(2,'0')}:${(s%60).toString().padStart(2,'0')}` }

onMounted(() => {
  getCameras()
  // 延迟初始化3D场景，等待DOM就绪
  setTimeout(() => {
    init3DScene()
  }, 500)
})
onUnmounted(() => { stopCamera(); if (recordingTime.value) clearInterval(recordingTime.value) })
watch(selectedCameraId, () => { if (isStreaming.value) { stopCamera(); startCamera() } })
</script>

<template>
<div class="app">
  <header class="header">
    <div class="logo"><span class="logo-icon">🎭</span><span class="logo-text">XRShowMaster</span></div>
    <nav class="tabs">
      <button class="tab" :class="{active:activeTab==='scene'}" @click="activeTab='scene'">🎬 场景</button>
      <button class="tab" :class="{active:activeTab==='material'}" @click="activeTab='material'">📁 素材</button>
      <button class="tab" :class="{active:activeTab==='lens'}" @click="activeTab='lens'">📷 镜头</button>
      <button class="tab" :class="{active:activeTab==='live'}" @click="activeTab='live'">📡 直播</button>
      <button class="tab" :class="{active:activeTab==='record'}" @click="activeTab='record'">⏺ 录屏</button>
    </nav>
    <div class="header-actions">
      <select v-model="selectedCameraId" class="select-camera" v-if="cameras.length">
        <option v-for="c in cameras" :key="c.deviceId" :value="c.deviceId">{{ c.label||'摄像头' }}</option>
      </select>
      <button v-if="!isStreaming" @click="startCamera" class="btn-start">开启摄像头</button>
      <button v-else @click="stopCamera" class="btn-stop">关闭摄像头</button>
    </div>
  </header>

  <div class="main">
    <aside class="sidebar-left">
      <div v-if="activeTab==='scene'" class="panel">
        <h3 class="panel-title">3D 虚拟背景</h3>
        <div class="prop-item"><label class="switch"><input type="checkbox" v-model="enable3DScene"><span class="slider"></span></label><span>启用 3D 背景</span></div>
        <div v-if="enable3DScene" class="scene-grid">
          <div v-for="s in threeDScenes" :key="s.id" class="scene-item" :class="{active:current3DScene===s.id}" @click="switch3DScene(s.id)">
            <div class="scene-thumb">{{ s.icon }}</div><span>{{ s.name }}</span>
          </div>
        </div>
      </div>
      <div v-if="activeTab==='material'" class="panel">
        <h3 class="panel-title">素材库</h3>
        <div class="material-grid">
          <div v-for="m in materials" :key="m.id" class="material-item"><div class="material-thumb">{{ m.icon }}</div><span>{{ m.name }}</span></div>
        </div>
      </div>
      <div v-if="activeTab==='lens'" class="panel">
        <h3 class="panel-title">镜头切换</h3>
        <div class="lens-list">
          <div v-for="l in lenses" :key="l.id" class="lens-item" :class="{active:l.active}" @click="switchLens(l.id)">
            <span class="lens-icon">{{ l.icon }}</span><span>{{ l.name }}</span>
          </div>
        </div>
        <div class="lens-controls">
          <button @click="switchLens(lenses[(lenses.findIndex(x=>x.id===activeLens)+lenses.length-1)%lenses.length].id)">◀</button>
          <span>{{ lenses.find(x=>x.id===activeLens)?.name }}</span>
          <button @click="switchLens(lenses[(lenses.findIndex(x=>x.id===activeLens)+1)%lenses.length].id)">▶</button>
        </div>
      </div>
      <div v-if="activeTab==='live'" class="panel">
        <h3 class="panel-title">直播推流</h3>
        <div class="form-group"><label>推流地址</label><input v-model="live.url" class="input" placeholder="rtmp://..."></div>
        <div class="form-group"><label>推流密钥</label><input v-model="live.key" class="input" type="password"></div>
        <button v-if="!live.enabled" class="btn-primary" @click="live.enabled=true">开始直播</button>
        <button v-else class="btn-danger" @click="live.enabled=false">停止直播</button>
      </div>
      <div v-if="activeTab==='record'" class="panel">
        <h3 class="panel-title">录屏设置</h3>
        <div class="form-group"><label>格式</label><select v-model="record.format" class="input"><option value="mp4">MP4</option><option value="webm">WebM</option></select></div>
        <div class="form-group"><label>帧率: {{ record.fps }}</label><input v-model.number="record.fps" type="range" min="24" max="60" class="range"></div>
        <div v-if="isRecording" class="recording-info"><span>🔴</span><span>{{ formatTime(recordingTime) }}</span></div>
        <button v-if="!isRecording" class="btn-record" @click="startRecording">开始录制</button>
        <button v-else class="btn-stop" @click="stopRecording">停止录制</button>
      </div>
    </aside>

    <main class="preview">
      <video ref="videoRef" class="video-hidden" muted></video>
      <canvas ref="previewCanvas" class="canvas-process"></canvas>
      <canvas id="three-canvas" class="canvas-three" :class="{active: enable3DScene && isStreaming}"></canvas>
      <canvas ref="outputCanvas" class="canvas-output"></canvas>
      <div v-if="!isStreaming" class="preview-empty"><span>📷</span><p>点击"开启摄像头"开始预览</p></div>
      <div class="lens-overlay"><span>{{ lenses.find(x=>x.id===activeLens)?.name }}</span></div>
    </main>

    <aside class="sidebar-right">
      <div class="panel">
        <h3 class="panel-title">绿幕抠像</h3>
        <div class="prop-item"><label class="switch"><input type="checkbox" v-model="chromaKey.enabled"><span class="slider"></span></label><span>启用</span></div>
        <div class="form-group"><label>颜色</label><input v-model="chromaKey.color" type="color" class="color-input"></div>
        <div class="form-group"><label>相似度: {{ chromaKey.similarity }}</label><input v-model.number="chromaKey.similarity" type="range" min="0" max="100" class="range"></div>
        <div class="form-group"><label>平滑度: {{ chromaKey.smoothness }}</label><input v-model.number="chromaKey.smoothness" type="range" min="0" max="100" class="range"></div>
        <div class="form-group"><label>去溢色: {{ chromaKey.spillRemoval }}</label><input v-model.number="chromaKey.spillRemoval" type="range" min="0" max="100" class="range"></div>
      </div>
      <div class="panel">
        <h3 class="panel-title">调色</h3>
        <div class="form-group"><label>亮度: {{ color.brightness }}</label><input v-model.number="color.brightness" type="range" min="-100" max="100" class="range"></div>
        <div class="form-group"><label>对比度: {{ color.contrast }}</label><input v-model.number="color.contrast" type="range" min="-100" max="100" class="range"></div>
        <div class="form-group"><label>饱和度: {{ color.saturation }}</label><input v-model.number="color.saturation" type="range" min="-100" max="100" class="range"></div>
        <div class="form-group"><label>色温: {{ color.temperature }}</label><input v-model.number="color.temperature" type="range" min="-100" max="100" class="range"></div>
      </div>
      <div class="panel">
        <h3 class="panel-title">特效</h3>
        <div class="form-group"><label>模糊: {{ effect.blur }}</label><input v-model.number="effect.blur" type="range" min="0" max="20" class="range"></div>
        <div class="form-group"><label>阴影: {{ effect.shadow }}</label><input v-model.number="effect.shadow" type="range" min="0" max="100" class="range"></div>
        <div class="form-group"><label>高光: {{ effect.highlight }}</label><input v-model.number="effect.highlight" type="range" min="0" max="100" class="range"></div>
        <div class="form-group"><label>暗角: {{ effect.vignette }}</label><input v-model.number="effect.vignette" type="range" min="0" max="100" class="range"></div>
      </div>
    </aside>
  </div>

  <footer class="timeline">
    <div class="timeline-controls">
      <button class="btn-timeline">⏮</button><button class="btn-timeline">⏪</button><button class="btn-timeline btn-play">▶</button>
      <button class="btn-timeline">⏩</button><button class="btn-timeline">⏭</button>
    </div>
    <div class="timeline-time"><span>00:00:00</span><span>/</span><span>00:00:00</span></div>
    <div class="timeline-tracks">
      <div class="track"><div class="track-header"><span>🎬</span><span>视频轨道</span></div><div class="track-content"></div></div>
      <div class="track"><div class="track-header"><span>🔊</span><span>音频轨道</span></div><div class="track-content"></div></div>
      <div class="track"><div class="track-header"><span>📝</span><span>字幕轨道</span></div><div class="track-content"></div></div>
    </div>
  </footer>
</div>
</template>

<style scoped>
*{margin:0;padding:0;box-sizing:border-box}
.app{width:100vw;height:100vh;background:#1a1a2e;color:#fff;display:flex;flex-direction:column;font-family:-apple-system,sans-serif}
.header{height:56px;background:linear-gradient(90deg,#16213e,#1a1a2e);display:flex;align-items:center;padding:0 16px;border-bottom:1px solid #333}
.logo{display:flex;align-items:center;gap:8px;margin-right:32px}
.logo-icon{font-size:24px}
.logo-text{font-size:18px;font-weight:bold;background:linear-gradient(90deg,#00d9ff,#00ff88);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.tabs{display:flex;gap:4px;flex:1}
.tab{padding:8px 16px;background:0 0;border:none;color:#888;cursor:pointer;border-radius:6px}
.tab:hover{background:rgba(255,255,255,.05);color:#fff}
.tab.active{background:linear-gradient(90deg,#00d9ff20,#00ff8820);color:#00d9ff}
.header-actions{display:flex;align-items:center;gap:12px}
.select-camera{padding:6px 12px;background:#0a0a15;border:1px solid #333;border-radius:4px;color:#fff}
.btn-start{padding:8px 20px;background:linear-gradient(90deg,#00d9ff,#00ff88);border:none;border-radius:6px;color:#000;font-weight:bold;cursor:pointer}
.btn-stop{padding:8px 20px;background:#ff4757;border:none;border-radius:6px;color:#fff;font-weight:bold;cursor:pointer}
.btn-primary{padding:10px 20px;background:linear-gradient(90deg,#00d9ff,#00ff88);border:none;border-radius:6px;color:#000;font-weight:bold;cursor:pointer;width:100%}
.btn-danger{padding:10px 20px;background:#ff4757;border:none;border-radius:6px;color:#fff;font-weight:bold;cursor:pointer;width:100%}
.btn-record{padding:10px 20px;background:#ff0000;border:none;border-radius:6px;color:#fff;font-weight:bold;cursor:pointer;width:100%}
.main{flex:1;display:flex;overflow:hidden}
.sidebar-left,.sidebar-right{width:260px;background:#0f0f1a;overflow-y:auto}
.sidebar-right{border-left:1px solid #333}
.panel{padding:16px;border-bottom:1px solid #222}
.panel-title{font-size:13px;color:#00d9ff;margin-bottom:12px;text-transform:uppercase;letter-spacing:1px}
.scene-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:8px}
.scene-item{background:#1a1a2e;border-radius:8px;padding:8px;cursor:pointer;border:2px solid transparent;text-align:center}
.scene-item:hover{border-color:#333}
.scene-thumb{height:60px;background:#0a0a15;border-radius:4px;display:flex;align-items:center;justify-content:center;font-size:24px;margin-bottom:6px}
.scene-name{font-size:12px;color:#aaa}
.material-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.material-item{background:#1a1a2e;border-radius:6px;padding:6px;cursor:pointer}
.material-thumb{height:50px;background:#0a0a15;border-radius:4px;display:flex;align-items:center;justify-content:center}
.material-name{font-size:10px;color:#888;margin-top:4px}
.lens-list{display:flex;flex-direction:column;gap:8px;margin-bottom:16px}
.lens-item{display:flex;align-items:center;gap:12px;padding:12px;background:#1a1a2e;border-radius:8px;cursor:pointer;border:2px solid transparent}
.lens-item:hover{background:#222}
.lens-item.active{border-color:#00d9ff;background:linear-gradient(90deg,#00d9ff20,#00ff8820)}
.lens-icon{font-size:24px}
.lens-controls{display:flex;align-items:center;justify-content:center;gap:16px;margin-top:12px}
.lens-controls button{width:40px;height:40px;background:#1a1a2e;border:1px solid #333;border-radius:50%;color:#fff;cursor:pointer}
.form-group{margin-bottom:12px}
.form-group label{display:block;font-size:12px;color:#888;margin-bottom:6px}
.input{width:100%;padding:8px 12px;background:#0a0a15;border:1px solid #333;border-radius:4px;color:#fff;font-size:13px}
.range{width:100%;height:4px;background:#333;border-radius:2px;appearance:none}
.range::-webkit-slider-thumb{appearance:none;width:12px;height:12px;background:#00d9ff;border-radius:50%;cursor:pointer}
.color-input{width:100%;height:30px;padding:2px;background:#0a0a15;border:1px solid #333;border-radius:4px;cursor:pointer}
.prop-item{display:flex;align-items:center;gap:12px;margin-bottom:12px}
.switch{position:relative;width:44px;height:24px}
.switch input{opacity:0;width:0;height:0}
.slider{position:absolute;cursor:pointer;top:0;left:0;right:0;bottom:0;background:#333;border-radius:24px;transition:.4s}
.slider:before{position:absolute;content:"";height:18px;width:18px;left:3px;bottom:3px;background:#fff;border-radius:50%;transition:.4s}
.switch input:checked+.slider{background:#00d9ff}
.switch input:checked+.slider:before{transform:translateX(20px)}
.preview{flex:1;position:relative;background:#000;display:flex;align-items:center;justify-content:center}
.video-hidden,.canvas-process{position:absolute;width:1px;height:1px;opacity:0}
.canvas-output,.canvas-three{width:100%;height:100%;position:absolute;top:0;left:0;object-fit:contain}
.canvas-three{opacity:0;transition:opacity .5s}
.canvas-three.active{opacity:1}
.preview-empty{position:absolute;color:#666;text-align:center}
.preview-empty span{font-size:64px;display:block}
.lens-overlay{position:absolute;bottom:20px;left:50%;transform:translateX(-50%);background:rgba(0,0,0,.7);padding:8px 20px;border-radius:20px}
.recording-info{display:flex;align-items:center;justify-content:center;gap:8px;margin-bottom:12px;font-size:18px;color:#ff0000}
.timeline{height:120px;background:#0a0a15;border-top:1px solid #333;display:flex;align-items:center;padding:0 16px;gap:24px}
.timeline-controls{display:flex;gap:8px}
.btn-timeline{width:36px;height:36px;background:#1a1a2e;border:1px solid #333;border-radius:4px;color:#fff;cursor:pointer}
.btn-play{background:#00d9ff;color:#000}
.timeline-time{font-size:14px;color:#888}
.timeline-time span:first-child{color:#fff}
.timeline-tracks{flex:1;display:flex;gap:8px}
.track{flex:1;background:#1a1a2e;border-radius:6px;padding:8px}
.track-header{display:flex;align-items:center;gap:8px;margin-bottom:8px;font-size:12px;color:#888}
.track-content{height:40px;background:#0a0a15;border-radius:4px}
</style>
