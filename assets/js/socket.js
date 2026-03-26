import { Socket } from 'phoenix'

import UUID from './uuid'

const SOCKET = new Socket('/socket', {
  params: {
    uuid: UUID,
  },
})
SOCKET.connect()
export default SOCKET
