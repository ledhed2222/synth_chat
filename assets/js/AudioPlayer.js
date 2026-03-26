import { ViewHook } from 'phoenix_live_view'

import SOCKET from './socket'
import UUID from './uuid'

export default class AudioPlayer extends ViewHook {
  mounted() {
    this.channel = null
    this.peerConnection = null
    this.peerId = null

    this.handleEvent('unmute_audio', () => {
      this.el.muted = false
      if (this.el.srcObject) {
        this.el
          .play()
          .catch((error) =>
            console.error('Error starting audio playback:', error),
          )
      }
      this.pushEvent('connection_status', { connected: true })
    })

    this.handleEvent('mute_audio', () => {
      this.el.muted = true
      this.pushEvent('connection_status', { connected: false })
    })

    // Connect immediately so the jitter buffer warms up before the user unmutes
    this.connect()
  }

  connect() {
    console.log('Connecting WebRTC audio stream (muted)...')

    this.peerId = UUID
    this.channel = SOCKET.channel(`audio:${this.peerId}`, {})

    this.channel
      .join()
      .receive('ok', (response) => {
        console.log('Joined audio channel', response)
        this.setupWebRTC()
      })
      .receive('error', (resp) => {
        console.error('Unable to join', resp)
      })

    // Handle signaling messages from Membrane
    this.channel.on(`audio:${this.peerId}`, (msg) => {
      console.log('Received WebRTC message:', msg)
      this.handleSignal(msg)
    })
  }

  setupWebRTC() {
    // Create RTCPeerConnection
    const stunServer = this.el.dataset.stunServer
    this.peerConnection = new RTCPeerConnection({
      iceServers: stunServer ? [{ urls: stunServer }] : [],
    })

    // Handle incoming audio tracks
    this.peerConnection.ontrack = (event) => {
      console.log('Received remote track:', event.track)
      console.log('Track settings:', event.track.getSettings())
      console.log('Track muted:', event.track.muted)
      console.log('Track enabled:', event.track.enabled)
      console.log('Streams:', event.streams)

      // Wait for the track to unmute
      event.track.onunmute = () => {
        console.log('Track unmuted!')
        this.playAudio(event)
      }

      event.track.onmute = () => {
        console.log('Track muted!')
      }

      // Set up the stream but don't play yet — wait for user interaction (unmute click)
      this.playAudio(event)
    }

    // Handle ICE candidates
    this.peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        console.log('Sending ICE candidate')
        const candidateMsg = {
          type: 'ice_candidate',
          data: event.candidate.toJSON(),
        }
        this.channel.push(`audio:${this.peerId}`, JSON.stringify(candidateMsg))
      }
    }

    // Handle connection state changes
    this.peerConnection.onconnectionstatechange = () => {
      console.log('Connection state:', this.peerConnection.connectionState)
      if (this.peerConnection.connectionState === 'connected') {
        this.pushEvent('connection_status', { connected: true })
      } else if (
        this.peerConnection.connectionState === 'failed' ||
        this.peerConnection.connectionState === 'disconnected'
      ) {
        this.pushEvent('connection_status', { connected: false })
      }
    }

    // Wait for offer from server (don't create one ourselves)
    console.log('Waiting for offer from server...')
  }

  handleSignal(msg) {
    const { type, data } = msg

    switch (type) {
      case 'sdp_offer':
      case 'offer': {
        console.log('Received offer from server, creating answer')
        // Membrane sends {type: 'sdp_offer', data: {type: 'offer', sdp: '...'}}
        const offerData = data || msg
        this.peerConnection
          .setRemoteDescription(new RTCSessionDescription(offerData))
          .then(() => {
            return this.peerConnection.createAnswer()
          })
          .then((answer) => {
            return this.peerConnection.setLocalDescription(answer)
          })
          .then(() => {
            console.log('Sending answer to server')
            // Send answer in the format Membrane expects
            const answerMsg = {
              type: 'sdp_answer',
              data: this.peerConnection.localDescription.toJSON(),
            }
            this.channel.push(`audio:${this.peerId}`, JSON.stringify(answerMsg))
          })
          .catch((error) => {
            console.error('Error handling offer:', error)
          })
        break
      }

      case 'ice_candidate':
      case 'candidate': {
        console.log('Adding ICE candidate')
        // Membrane sends {type: 'ice_candidate', data: {candidate: '...', ...}}
        const candidateData = data || msg
        this.peerConnection
          .addIceCandidate(new RTCIceCandidate(candidateData))
          .catch((error) => {
            console.error('Error adding ICE candidate:', error)
          })
        break
      }

      default:
        console.warn('Unknown signal type:', type)
    }
  }

  playAudio(event) {
    console.log(this.el)
    if (!this.el) {
      return
    }

    // Create MediaStream from track if streams array is empty
    let stream
    if (event.streams && event.streams.length > 0) {
      stream = event.streams[0]
    } else {
      stream = new MediaStream([event.track])
    }

    this.el.srcObject = stream
    this.el.muted = true
    this.el.volume = 1.0
  }

  destroyed() {
    if (this.peerConnection) {
      this.peerConnection.close()
    }
    if (this.channel) {
      this.channel.leave()
    }
  }
}
