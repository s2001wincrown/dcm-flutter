package dcm.player

import android.content.Context
import android.util.DisplayMetrics
import android.view.Display
import org.json.JSONObject

/**
 * 扩展屏输出序号的稳定映射。
 *
 * 输出序号原来是“显示器在排序列表中的下标”，一旦插入/移除显示器或系统重新
 * 分配 displayId，同一块屏拿到的序号就会变化，导致内容串屏。这里以
 * “显示器名称 + 物理分辨率”作为持久化键（displayId 不跨重启稳定），首次
 * 见到的显示器分配最小空闲序号，之后拔插同一块屏仍拿回原序号。
 *
 * 主屏固定为输出 0；扩展屏从 1 开始编号。
 */
object DisplayOutputRegistry {

    private const val PREFS_NAME = "dcm_multiscreen"
    private const val KEY_MAP = "display_outputs"
    private const val MAX_ENTRIES = 32

    private val outputs = LinkedHashMap<String, Int>()
    private var loaded = false

    @Synchronized
    fun resolve(context: Context, displays: List<Display>): Map<Int, Int> {
        load(context)

        val result = LinkedHashMap<Int, Int>()
        val used = HashSet<Int>()
        val seenKeys = HashMap<String, Int>()
        val pending = ArrayList<Pair<Display, String>>()

        displays.forEach { display ->
            if (display.displayId == Display.DEFAULT_DISPLAY) {
                result[display.displayId] = 0
                used.add(0)
                return@forEach
            }
            val key = uniqueKey(display, seenKeys)
            pending.add(display to key)
            val mapped = outputs[key]
            if (mapped != null && mapped > 0 && used.add(mapped)) {
                result[display.displayId] = mapped
            }
        }

        var next = 1
        pending.forEach { (display, key) ->
            if (result.containsKey(display.displayId)) return@forEach
            while (used.contains(next)) next++
            result[display.displayId] = next
            outputs[key] = next
            used.add(next)
            next++
        }

        trim(used)
        save(context)
        return result
    }

    /** 同一型号显示器可能有多块，用出现次数区分：#2、#3…… */
    private fun uniqueKey(display: Display, seen: MutableMap<String, Int>): String {
        val base = stableKey(display)
        val count = (seen[base] ?: 0) + 1
        seen[base] = count
        return if (count == 1) base else "$base#$count"
    }

    private fun stableKey(display: Display): String {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        display.getRealMetrics(metrics)
        val longSide = maxOf(metrics.widthPixels, metrics.heightPixels)
        val shortSide = minOf(metrics.widthPixels, metrics.heightPixels)
        return "${display.name ?: ""}@${longSide}x$shortSide"
    }

    private fun trim(used: Set<Int>) {
        if (outputs.size <= MAX_ENTRIES) return
        val iterator = outputs.entries.iterator()
        while (outputs.size > MAX_ENTRIES && iterator.hasNext()) {
            if (!used.contains(iterator.next().value)) iterator.remove()
        }
    }

    private fun load(context: Context) {
        if (loaded) return
        loaded = true
        val raw = prefs(context).getString(KEY_MAP, null) ?: return
        try {
            val json = JSONObject(raw)
            val keys = json.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                val value = json.optInt(key, -1)
                if (value > 0) outputs[key] = value
            }
        } catch (_: Throwable) {
            // 配置损坏时按空映射处理，重新分配即可。
        }
    }

    private var savedSnapshot = ""

    private fun save(context: Context) {
        val json = JSONObject()
        outputs.forEach { (key, value) -> json.put(key, value) }
        val snapshot = json.toString()
        if (snapshot == savedSnapshot) return
        savedSnapshot = snapshot
        prefs(context).edit().putString(KEY_MAP, snapshot).apply()
    }

    private fun prefs(context: Context) = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
