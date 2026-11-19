package dev.creapolis.pepinillo.appfunctions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Guard tests for [res/xml/app_metadata.xml] (issue #918).
 *
 * Google Play Console validates the app-level AppFunctions metadata against the
 * current androidx.appfunctions attribute names: since 1.0.0-beta01 the
 * agent-facing attribute is `appfn:instructions` (the legacy `appfn:description`
 * is ignored by the validator) and `appfn:displayDescription` must reference a
 * non-empty user-visible string. An AAB with the legacy attribute alone is
 * rejected at upload with "App metadata xml is missing or has empty description
 * or display description".
 */
class AppMetadataXmlTest {

    private val repoRoot: File by lazy {
        generateSequence(File(System.getProperty("user.dir"))) { it.parentFile }
            .firstOrNull { it.resolve("android/app/src/main/res/xml/app_metadata.xml").exists() }
            ?: error("Could not locate app_metadata.xml from ${System.getProperty("user.dir")}")
    }

    private fun appMetadataFile() = repoRoot.resolve("android/app/src/main/res/xml/app_metadata.xml")

    private fun parseAppMetadata(): org.w3c.dom.Element {
        val doc = DocumentBuilderFactory.newInstance().apply { isNamespaceAware = true }
            .newDocumentBuilder().parse(appMetadataFile())
        return doc.documentElement
    }

    private fun attribute(element: org.w3c.dom.Element, localName: String): String? {
        val attributes = element.attributes
        for (i in 0 until attributes.length) {
            val attribute = attributes.item(i)
            if (attribute.localName == localName) return attribute.nodeValue
        }
        return null
    }

    private fun stringValuesFor(name: String, localeDir: String): String {
        val file = repoRoot.resolve("android/app/src/main/res/$localeDir/strings.xml")
        assertTrue("Missing strings file: $file", file.exists())
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
        val nodes = doc.getElementsByTagName("string")
        for (i in 0 until nodes.length) {
            val node = nodes.item(i).attributes.getNamedItem("name")
            if (node?.nodeValue == name) return nodes.item(i).textContent.trim()
        }
        error("String '$name' not found in $file")
    }

    @Test
    fun `app metadata declares non-empty agent instructions`() {
        val root = parseAppMetadata()
        assertEquals("AppFunctionAppMetadata", root.localName)

        val instructions = attribute(root, "instructions")
        assertNotNull("appfn:instructions is missing (legacy appfn:description is not accepted by Play)", instructions)
        assertTrue("appfn:instructions is empty", instructions!!.isNotBlank())
        assertTrue("appfn:instructions should describe Pepinillo", instructions.contains("Pepinillo"))
    }

    @Test
    fun `app metadata does not use the legacy description attribute`() {
        val root = parseAppMetadata()
        assertNull(
            "Legacy appfn:description found; Play Console ignores it — use appfn:instructions",
            attribute(root, "description"),
        )
    }

    @Test
    fun `display description references a string defined in every locale`() {
        val root = parseAppMetadata()

        val reference = attribute(root, "displayDescription")
        assertNotNull("appfn:displayDescription is missing", reference)
        assertTrue("appfn:displayDescription must reference a string resource", reference!!.startsWith("@string/"))

        val name = reference.removePrefix("@string/")
        val english = stringValuesFor(name, "values")
        val spanish = stringValuesFor(name, "values-es")
        val portuguese = stringValuesFor(name, "values-pt")

        assertTrue(english.isNotBlank())
        assertTrue(spanish.isNotBlank())
        assertTrue(portuguese.isNotBlank())
        assertFalse("Spanish translation must differ from the default", spanish == english)
        assertFalse("Portuguese translation must differ from the default", portuguese == english)
    }
}
