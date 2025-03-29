/// <reference types="bun-types" />

// @ts-nocheck
import { describe, expect, it } from "bun:test";
import {
  runTerraformApply,
  runTerraformInit,
  testRequiredVariables,
} from "../test";

describe("cursor-mcp", async () => {
  await runTerraformInit(import.meta.dir);

  testRequiredVariables(import.meta.dir, {
    agent_id: "foo",
  });

  it("does not create script when no servers are specified", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
    });
    expect(state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    )).toBeUndefined();
    expect(state.outputs.mcp_servers_configured.value).toEqual([]);
  });

  it("creates script with single server", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_servers: {
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        }
      }
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["weather"]);
  });

  it("creates script with multiple servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_servers: {
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        },
        github: {
          name: "github-tools",
          command: "npx",
          args: ["-y", "@mcp/github-tools"],
          env: {
            GITHUB_TOKEN: "test-token"
          }
        }
      }
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["weather", "github"]);
  });

  it("uses custom config directory", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      mcp_config_dir: "/custom/path",
      mcp_servers: {
        weather: {
          name: "weather",
          command: "npx",
          args: ["-y", "@modelcontextprotocol/server-weather"],
          env: {}
        }
      }
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    const script = coder_script?.instances[0].attributes.script as string;
    expect(script).toContain('MCP_CONFIG_DIR="/custom/path"');
  });

  // New tests for simplified configuration

  it("enables GitHub server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      github_token: "test-github-token"
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["github-tools"]);
    
    // Verify the script contains the correct configuration
    const script = coder_script?.instances[0].attributes.script as string;
    expect(script).toContain('GITHUB_TOKEN');
    expect(script).toContain('test-github-token');
  });

  it("enables Filesystem server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_filesystem: true,
      filesystem_path: "/custom/filesystem/path"
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["filesystem"]);
    
    // Verify the script contains the correct configuration
    const script = coder_script?.instances[0].attributes.script as string;
    expect(script).toContain('/custom/filesystem/path');
  });

  it("enables Weather server with flag", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    expect(state.outputs.mcp_servers_configured.value).toEqual(["weather"]);
  });

  it("combines simplified flags with custom servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      enable_weather: true,
      mcp_servers: {
        custom: {
          name: "custom-tool",
          command: "python",
          args: ["-m", "custom_mcp_tool"],
          env: {
            API_KEY: "test-api-key"
          }
        }
      }
    });
    
    const coder_script = state.resources.find(
      (res) => res.type === "coder_script" && res.name === "mcp-servers",
    );

    expect(coder_script).not.toBeUndefined();
    expect(coder_script?.instances.length).toBe(1);
    
    // Order isn't guaranteed in the output, so we check for inclusion instead
    const servers = state.outputs.mcp_servers_configured.value;
    expect(servers).toContain("github-tools");
    expect(servers).toContain("weather");
    expect(servers).toContain("custom");
    expect(servers.length).toBe(3);
  });

  // Tests for proxying functionality

  it("creates proxy apps when enabled", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true,
      enable_proxy: true
    });
    
    // Check that a proxy app was created
    const proxy_app = state.resources.find(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy" && res.instances[0].attributes.slug === "mcp-weather-proxy"
    );

    expect(proxy_app).not.toBeUndefined();
    expect(state.outputs.proxy_instructions.value).toContain("MCP servers are being proxied");
  });

  it("creates multiple proxy apps for multiple servers", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_github: true,
      enable_weather: true,
      enable_proxy: true
    });
    
    // Find all proxy apps
    const proxy_apps = state.resources.filter(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy"
    );

    expect(proxy_apps.length).toBe(2);
    
    // Check that proxies for both servers exist
    const slugs = proxy_apps.map(app => app.instances[0].attributes.slug);
    expect(slugs).toContain("mcp-weather-proxy");
    expect(slugs).toContain("mcp-github-tools-proxy");
  });

  it("does not create proxy apps when disabled", async () => {
    const state = await runTerraformApply(import.meta.dir, {
      agent_id: "foo",
      enable_weather: true,
      enable_proxy: false
    });
    
    // Check that no proxy app was created
    const proxy_app = state.resources.find(
      (res) => res.type === "coder_app" && res.name === "mcp-proxy"
    );

    expect(proxy_app).toBeUndefined();
    expect(state.outputs.proxy_instructions.value).toBeNull();
  });
});
