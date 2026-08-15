/*
 * This file is part of NovaCraft (https://github.com/Creeper100GB/NovaCraft)
 *
 * Copyright (c) 2015 - 2026 Creeper100GB
 *
 * NovaCraft is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * LiquidBounce is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with NovaCraft. If not, see <https://www.gnu.org/licenses/>.
 */
package net.ccbluex.liquidbounce.utils.movement

import net.ccbluex.liquidbounce.event.EventListener
import net.ccbluex.liquidbounce.event.events.GameTickEvent
import net.ccbluex.liquidbounce.event.events.PacketEvent
import net.ccbluex.liquidbounce.event.events.TransferOrigin
import net.ccbluex.liquidbounce.event.handler
import net.minecraft.network.protocol.game.ClientboundPlayerPositionPacket
import java.util.concurrent.atomic.AtomicInteger

/**
 * Centralizes setback (server position correction) detection.
 *
 * Many modules previously re-implemented the same `packet is ClientboundPlayerPositionPacket`
 * check independently. This tracker provides a single source of truth for:
 * - Whether a setback occurred within the current tick
 * - The total consecutive setback count
 *
 * Modules can consume the state via [consumeSetbackForTick] to avoid
 * multiple modules reacting to the same packet independently.
 */
object SetbackTracker : EventListener {

    private val consecutiveSetbacks = AtomicInteger()
    private var setbackThisTick = false

    val totalConsecutiveSetbacks: Int
        get() = consecutiveSetbacks.get()

    /**
     * Returns true once per game tick if a setback packet arrived since the last tick.
     * Subsequent calls in the same tick return false.
     */
    fun consumeSetbackForTick(): Boolean {
        val wasSetback = setbackThisTick
        setbackThisTick = false
        return wasSetback
    }

    /**
     * Resets the consecutive setback counter, e.g. after a successful
     * position sync or when the player is no longer flagged.
     */
    fun resetConsecutiveSetbacks() {
        consecutiveSetbacks.set(0)
    }

    @Suppress("unused")
    private val packetHandler = handler<PacketEvent> { event ->
        if (event.origin != TransferOrigin.INCOMING) {
            return@handler
        }

        if (event.packet is ClientboundPlayerPositionPacket) {
            setbackThisTick = true
            consecutiveSetbacks.incrementAndGet()
        }
    }

    @Suppress("unused")
    private val gameTickHandler = handler<GameTickEvent> {
        setbackThisTick = false
    }

}
