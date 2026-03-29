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
    this.peerId = UUID
    this.channel = SOCKET.channel(`audio:${this.peerId}`, {})

    this.channel
      .join()
      .receive('ok', () => this.setupWebRTC())
      .receive('error', (resp) => {
        console.error('Unable to join audio channel', resp)
      })

    this.channel.on(`audio:${this.peerId}`, (msg) => this.handleSignal(msg))
  }

  setupWebRTC() {
    const stunServer = this.el.dataset.stunServer
    this.peerConnection = new RTCPeerConnection({
      iceServers: stunServer ? [{ urls: stunServer }] : [],
    })

    this.peerConnection.ontrack = (event) => {
      event.track.onunmute = () => this.playAudio(event)
      this.playAudio(event)
    }

    this.peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        const candidateMsg = {
          type: 'ice_candidate',
          data: event.candidate.toJSON(),
        }
        this.channel.push(`audio:${this.peerId}`, JSON.stringify(candidateMsg))
      }
    }

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
  }

  handleSignal(msg) {
    const { type, data } = msg

    switch (type) {
      case 'sdp_offer':
      case 'offer': {
        const offerData = data || msg
        this.peerConnection
          .setRemoteDescription(new RTCSessionDescription(offerData))
          .then(() => this.peerConnection.createAnswer())
          .then((answer) => {
            // Chrome defaults to stereo=0 in its answer, causing mono decoding.
            // Force stereo=1 so Chrome configures its Opus decoder for 2 channels.
            let stereoSdp = answer.sdp
            if (/a=fmtp:111 /.test(stereoSdp)) {
              stereoSdp = stereoSdp.replace(
                /(a=fmtp:111 [^\r\n]*)/,
                (match) => match.includes('stereo=1') ? match : match + ';stereo=1'
              )
            } else {
              stereoSdp = stereoSdp.replace(
                /(a=rtpmap:111 [^\r\n]*\r?\n)/,
                '$1a=fmtp:111 minptime=10;useinbandfec=1;stereo=1\r\n'
              )
            }
            return this.peerConnection.setLocalDescription({ type: answer.type, sdp: stereoSdp })
          })
          .then(() => {
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
    if (!this.el) {
      return
    }

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
